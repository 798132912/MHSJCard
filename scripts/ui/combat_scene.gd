extends Control

const PLAYER_ID := "player_star"
const ENEMY_ID := "enemy_corrupted_student"
const LEVEL_ID := "level_demo_trial"

const TARGET_SELF := 10
const TARGET_SINGLE_ENEMY := 20
const TARGET_PLAYER := 30

const EFFECT_MODIFY_RESOURCE := 100
const EFFECT_DAMAGE := 200
const EFFECT_ATTACH_EFFECT := 300

const DAMAGE_NORMAL := 10
const DAMAGE_MAGIC := 20
const DAMAGE_CHARM := 30
const DAMAGE_PIERCE := 40
const DAMAGE_TRUE := 50
const DAMAGE_SHIELD_BREAK := 60

const RESOURCE_HP := 10
const RESOURCE_MAGIC := 20
const RESOURCE_MAGIC_MAX := 30
const RESOURCE_MAGIC_DEFENSE := 40
const RESOURCE_MAGIC_SHIELD := 50
const RESOURCE_AROUSAL := 60
const RESOURCE_SENSITIVITY := 70
const RESOURCE_CORRUPTION := 80

const STATUS_ICE_ARMOR := "300001"
const STATUS_TRANSFORM := "300002"

const GameDatabaseScript = preload("res://scripts/data/game_database.gd")
const CorruptedStudentAIScript = preload("res://scripts/enemy_ai/corrupted_student_ai.gd")
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

var database = GameDatabaseScript.new()
var enemy_ai = CorruptedStudentAIScript.new()
var next_instance_id := 1
var turn_count := 0
var phase := "setup"

var player := {}
var enemy := {}
var current_level := {}
var draw_pile: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
var exhaust_pile: Array[Dictionary] = []
var held_transform_card := {}
var pending_play_hand_index := -1
var enemy_action_cards: Array[String] = []
var enemy_intent_card_id := ""
var log_lines: Array[String] = []
var battle_log_expanded := false
var drag_play_hand_index := -1
var drag_arrow_start := Vector2.ZERO
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
@onready var hand_list: Control = $HandPanel/Margin/HandList
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var end_turn_button: Button = $StatusArea/ActionArea/EndTurnButton
@onready var player_unit_slot: Control = $BattleArea/PlayerUnitSlot
@onready var enemy_unit_slot: Control = $BattleArea/EnemyUnitSlot
@onready var target_arrow_layer: TargetArrowLayer = $TargetArrowLayer

func _ready() -> void:
	add_child(database)
	database.load_all()
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	_start_combat()

func _start_combat() -> void:
	next_instance_id = 1
	turn_count = 0
	phase = "player"
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	held_transform_card = {}
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

	player = {
		"id": str(character.get("id", "")),
		"name": str(character.get("name", "玩家")),
		"unit_type": str(character.get("unit_type", "player")),
		"max_hp": _to_int(character.get("max_hp", 30)),
		"hp": _to_int(character.get("max_hp", 30)),
		"base_draw_count": _to_int(character.get("base_draw_count", 5)),
		"base_hand_limit": _to_int(character.get("base_hand_limit", 10)),
		"human_base_magic_max": _to_int(character.get("human_base_magic_max", 0)),
		"magic": _to_int(character.get("human_base_magic_max", 0)),
		"magic_max": _to_int(character.get("human_base_magic_max", 0)),
		"magic_shield": _to_int(character.get("init_magic_shield", 0)),
		"magic_defense": _to_int(character.get("init_magic_defense", 0)),
		"arousal": _to_int(character.get("init_arousal", 0)),
		"arousal_max": _to_int(character.get("arousal_max", 100)),
		"sensitivity": _to_int(character.get("init_sensitivity", 0)),
		"corruption": _to_int(character.get("init_corruption", 0)),
		"form": "人类形态",
		"transformed": false,
		"statuses": [],
		"battle_image_path": str(character.get("battle_image_path", "")),
		"portrait_path": str(character.get("portrait_path", "")),
		"hit_motion_profile": str(character.get("hit_motion_profile", "bump")),
	}
	enemy = {
		"id": str(enemy_row.get("id", "")),
		"name": str(enemy_row.get("name", "敌人")),
		"unit_type": str(enemy_row.get("unit_type", "enemy")),
		"max_hp": _to_int(enemy_row.get("max_hp", 25)),
		"hp": _to_int(enemy_row.get("max_hp", 25)),
		"magic_shield": _to_int(enemy_row.get("init_magic_shield", 0)),
		"statuses": [],
		"battle_image_path": str(enemy_row.get("battle_image_path", "")),
		"portrait_path": str(enemy_row.get("portrait_path", "")),
		"hit_motion_profile": str(enemy_row.get("hit_motion_profile", "bump")),
	}

	_build_player_deck(str(character.get("starter_deck_id", "")), player["id"])
	_build_enemy_actions(str(enemy_row.get("starter_deck_id", "")), enemy["id"], str(enemy_row.get("action_ids", "")))
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

func _build_player_deck(deck_id: String, unit_id: String) -> void:
	for row in database.get_deck_rows(deck_id, unit_id):
		var card_id := str(row.get("card_id", ""))
		var count := _to_int(row.get("count", 1))
		var card: Dictionary = database.find_card(card_id)
		if card.is_empty() or str(card.get("owner_type", "player")) == "enemy":
			continue
		for i in range(count):
			draw_pile.append(_new_card_instance(card_id))

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

func _new_card_instance(card_id: String) -> Dictionary:
	var result := {
		"instance_id": next_instance_id,
		"card_id": card_id,
	}
	next_instance_id += 1
	return result

func _start_player_turn() -> void:
	if _is_combat_over():
		return
	turn_count += 1
	phase = "player"
	pending_play_hand_index = -1
	player["magic"] = player["magic_max"]
	_draw_cards(player["base_draw_count"])
	_log("第 %s 回合开始。玩家恢复魔力并抽牌。" % turn_count)
	_refresh_ui()

func _draw_cards(count: int) -> void:
	for i in range(count):
		if hand.size() >= player["base_hand_limit"]:
			if not draw_pile.is_empty():
				discard_pile.append(draw_pile.pop_front())
			continue
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
			_log("弃牌堆洗入抽牌堆。")
		hand.append(draw_pile.pop_front())

func _start_card_targeting(hand_index: int, global_position: Vector2) -> void:
	if phase != "player" or hand_index < 0 or hand_index >= hand.size():
		_cancel_card_targeting()
		return
	drag_play_hand_index = hand_index
	pending_play_hand_index = hand_index
	drag_arrow_start = global_position
	_update_card_targeting(hand_index, global_position)

func _update_card_targeting(hand_index: int, global_position: Vector2) -> void:
	if hand_index != drag_play_hand_index or drag_play_hand_index < 0 or drag_play_hand_index >= hand.size():
		return
	var card: Dictionary = database.find_card(str(hand[drag_play_hand_index].get("card_id", "")))
	var target_side := _target_side_at_global_position(global_position)
	var is_valid_target := target_side != "" and _is_valid_target_for_card(card, target_side)
	target_arrow_layer.show_arrow(
		target_arrow_layer.to_local(drag_arrow_start),
		target_arrow_layer.to_local(global_position),
		is_valid_target
	)

func _finish_card_targeting(hand_index: int, global_position: Vector2) -> void:
	if hand_index != drag_play_hand_index or hand_index < 0 or hand_index >= hand.size():
		_cancel_card_targeting()
		return
	var card: Dictionary = database.find_card(str(hand[hand_index].get("card_id", "")))
	var target_side := _target_side_at_global_position(global_position)
	if target_side == "" or not _is_valid_target_for_card(card, target_side):
		_cancel_card_targeting()
		return
	_cancel_card_targeting(false)
	_play_card(hand_index, target_side)

func _cancel_card_targeting(refresh_hand: bool = true) -> void:
	drag_play_hand_index = -1
	pending_play_hand_index = -1
	target_arrow_layer.hide_arrow()
	if refresh_hand:
		_refresh_hand()

func _play_card(hand_index: int, target_side: String = "") -> void:
	if phase != "player" or hand_index < 0 or hand_index >= hand.size():
		pending_play_hand_index = -1
		_refresh_hand()
		return

	var instance := hand[hand_index]
	var card: Dictionary = database.find_card(str(instance.get("card_id", "")))
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
	hand.remove_at(hand_index)
	_log("玩家使用 %s。" % str(card.get("name", "未知卡牌")))
	_resolve_card(card, "player", instance, target_side)

	if str(card.get("id", "")) == "card_star_transform":
		held_transform_card = instance
	elif _to_bool(card.get("exhaust", false)):
		exhaust_pile.append(instance)
	else:
		discard_pile.append(instance)

	_post_effect_checks()
	_refresh_ui()

func _resolve_card(card: Dictionary, source_side: String, card_instance: Dictionary = {}, target_side: String = "") -> void:
	var effect_ids := str(card.get("effect_ids", "")).split(";", false)
	for effect_id in effect_ids:
		var effect: Dictionary = database.find_card_effect(effect_id)
		if effect.is_empty():
			_log("找不到效果 %s。" % effect_id)
			continue
		_resolve_effect(effect, card, source_side, card_instance, target_side)
		if _is_combat_over():
			return

func _resolve_effect(effect: Dictionary, card: Dictionary, source_side: String, card_instance: Dictionary = {}, target_side: String = "") -> void:
	var target := _select_target(card, source_side, target_side)
	var effect_type := _to_int(effect.get("effect_type", 0))
	match effect_type:
		EFFECT_MODIFY_RESOURCE:
			_apply_resource_effect(effect, target)
		EFFECT_DAMAGE:
			_apply_damage_effect(effect, target, source_side)
		EFFECT_ATTACH_EFFECT:
			_apply_attach_effect(effect, target, card_instance)
		_:
			_log("暂未支持效果类型 %s。" % effect_type)

func _select_target(card: Dictionary, source_side: String, target_side: String = "") -> Dictionary:
	if target_side == "enemy":
		return enemy
	if target_side == "player":
		return player
	var target_type := _to_int(card.get("target", TARGET_SELF))
	if target_type == TARGET_SINGLE_ENEMY:
		return enemy
	if target_type == TARGET_PLAYER:
		return player
	if target_type == TARGET_SELF:
		return player if source_side == "player" else enemy
	return player if source_side == "player" else enemy

func _target_side_at_global_position(global_position: Vector2) -> String:
	if enemy_unit_view != null and enemy_unit_view.get_global_rect().has_point(global_position):
		return "enemy"
	if player_unit_view != null and player_unit_view.get_global_rect().has_point(global_position):
		return "player"
	return ""

func _is_valid_target_for_card(card: Dictionary, target_side: String) -> bool:
	if card.is_empty():
		return false
	var target_type := _to_int(card.get("target", TARGET_SELF))
	if target_type == TARGET_SINGLE_ENEMY:
		return target_side == "enemy"
	if target_type == TARGET_PLAYER or target_type == TARGET_SELF:
		return target_side == "player"
	return false

func _apply_resource_effect(effect: Dictionary, target: Dictionary) -> void:
	var parts := _parse_value(effect.get("value", ""))
	if parts.size() < 2:
		return
	var resource_type := parts[0]
	var amount := parts[1]
	match resource_type:
		RESOURCE_HP:
			target["hp"] = clampi(_to_int(target.get("hp", 0)) + amount, 0, _to_int(target.get("max_hp", 0)))
			_log("%s 生命值变化 %+d。" % [target["name"], amount])
		RESOURCE_MAGIC:
			player["magic"] = clampi(player["magic"] + amount, 0, player["magic_max"])
			_log("玩家获得 %d 点当前魔力。" % amount)
		RESOURCE_MAGIC_MAX:
			player["magic_max"] += amount
			player["magic"] = min(player["magic"], player["magic_max"])
			_log("玩家魔力上限 %+d。" % amount)
		RESOURCE_MAGIC_DEFENSE:
			player["magic_defense"] = max(0, player["magic_defense"] + amount)
			player_magic_defense_bar_max = max(player_magic_defense_bar_max, _to_int(player["magic_defense"]))
			_log("玩家获得 %d 点魔力防御。" % amount)
		RESOURCE_MAGIC_SHIELD:
			target["magic_shield"] = max(0, _to_int(target.get("magic_shield", 0)) + amount)
			if target.get("unit_type", "") == "enemy":
				enemy_magic_defense_bar_max = max(enemy_magic_defense_bar_max, _unit_magic_defense_value(target))
			_log("%s 获得 %d 点魔力护盾。" % [target["name"], amount])
		RESOURCE_AROUSAL:
			var gained := ceili(float(amount) * (1.0 + float(player["sensitivity"]) / 100.0))
			player["arousal"] = clampi(player["arousal"] + gained, 0, player["arousal_max"])
			_log("玩家发情值提升 %d。" % gained)
		RESOURCE_SENSITIVITY:
			player["sensitivity"] = max(0, player["sensitivity"] + amount)
			_log("玩家敏感值提升 %d。" % amount)
		RESOURCE_CORRUPTION:
			player["corruption"] = max(0, player["corruption"] + amount)
			_log("玩家堕落值提升 %d。" % amount)

func _apply_damage_effect(effect: Dictionary, target: Dictionary, source_side: String) -> void:
	var parts := _parse_value(effect.get("value", ""))
	if parts.size() < 2:
		return
	var damage_type := parts[0]
	var amount := _calculate_damage(parts[1], damage_type, source_side)
	var remaining := amount

	if damage_type == DAMAGE_SHIELD_BREAK:
		var shield_loss: int = min(_to_int(target.get("magic_shield", 0)), remaining)
		target["magic_shield"] -= shield_loss
		_log("%s 的魔力护盾被破坏 %d 点。" % [target["name"], shield_loss])
		return

	if damage_type != DAMAGE_TRUE and damage_type != DAMAGE_PIERCE:
		var shield_loss: int = min(_to_int(target.get("magic_shield", 0)), remaining)
		target["magic_shield"] -= shield_loss
		remaining -= shield_loss

	if damage_type != DAMAGE_TRUE and target.has("magic_defense"):
		var defense_loss: int = min(_to_int(target.get("magic_defense", 0)), remaining)
		target["magic_defense"] -= defense_loss
		remaining -= defense_loss

	target["hp"] = max(0, _to_int(target.get("hp", 0)) - remaining)
	_log("%s 受到 %d 点伤害。" % [target["name"], amount])
	_animate_hit(target)

func _calculate_damage(base_amount: int, damage_type: int, source_side: String) -> int:
	var result := base_amount
	if source_side == "player" and damage_type == DAMAGE_MAGIC:
		result -= floori(float(player["arousal"]) / 10.0)
	elif source_side == "player" and damage_type == DAMAGE_CHARM:
		result += floori(float(player["arousal"]) / 10.0)
	return max(0, result)

func _apply_attach_effect(effect: Dictionary, target: Dictionary, card_instance: Dictionary = {}) -> void:
	var parts := _parse_value(effect.get("value", ""))
	if parts.size() < 2:
		return
	var status_id := str(parts[0])
	var stack := parts[1]
	if status_id == STATUS_TRANSFORM:
		player["transformed"] = true
		player["form"] = "魔法少女形态"
		_add_status(player, "变身状态", stack)
		_log("玩家进入魔法少女形态。")
	elif status_id == STATUS_ICE_ARMOR:
		_add_status(target, "冰甲", stack)
		_log("%s 获得 %d 层冰甲。" % [target["name"], stack])

func _add_status(target: Dictionary, status_name: String, stack: int) -> void:
	var statuses: Array = target.get("statuses", [])
	for status in statuses:
		if status.get("name", "") == status_name:
			status["stack"] += stack
			target["statuses"] = statuses
			return
	statuses.append({"name": status_name, "stack": stack})
	target["statuses"] = statuses

func _on_end_turn_pressed() -> void:
	if phase != "player":
		return
	pending_play_hand_index = -1
	_log("玩家结束回合。")
	while not hand.is_empty():
		discard_pile.append(hand.pop_front())
	phase = "enemy"
	_refresh_ui()
	await get_tree().create_timer(0.35).timeout
	_run_enemy_turn()

func _run_enemy_turn() -> void:
	if _is_combat_over():
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
	var context := {
		"enemy_magic_shield": enemy.get("magic_shield", 0),
		"player_sensitivity": player.get("sensitivity", 0),
	}
	var chosen: String = enemy_ai.choose_action(context)
	if not enemy_action_cards.has(chosen) and not enemy_action_cards.is_empty():
		chosen = enemy_action_cards[0]
	enemy_intent_card_id = chosen

func _post_effect_checks() -> void:
	if player["transformed"] and player["magic_defense"] <= 0:
		player["transformed"] = false
		player["form"] = "人类形态"
		player["magic_max"] = player["human_base_magic_max"]
		player["magic"] = min(player["magic"], player["magic_max"])
		_remove_status(player, "变身状态")
		if not held_transform_card.is_empty():
			discard_pile.append(held_transform_card)
			held_transform_card = {}
		_log("魔力防御归零，玩家解除变身。")
	if player["arousal"] >= player["arousal_max"] and phase == "player":
		_log("玩家发情值达到上限，强制结束回合。")
		_on_end_turn_pressed()
	if enemy["hp"] <= 0:
		phase = "victory"
		_log("战斗胜利。")
	elif player["hp"] <= 0:
		phase = "defeat"
		_log("战斗失败。")

func _remove_status(target: Dictionary, status_name: String) -> void:
	var statuses: Array = target.get("statuses", [])
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].get("name", "") == status_name:
			statuses.remove_at(i)
	target["statuses"] = statuses

func _is_combat_over() -> bool:
	return phase == "victory" or phase == "defeat"

func _refresh_ui() -> void:
	turn_state_label.text = _phase_text()

	player_info.text = "形态 %s  发情值 %d/%d\n敏感 %d  堕落 %d\n状态 %s" % [
		player.get("form", "人类形态"),
		player.get("arousal", 0),
		player.get("arousal_max", 100),
		player.get("sensitivity", 0),
		player.get("corruption", 0),
		_status_text(player),
	]
	_refresh_magic_ui()
	var intent_card: Dictionary = database.find_card(enemy_intent_card_id)
	var intent_name := str(intent_card.get("name", "无"))
	_refresh_unit_views()
	enemy_info.text = "下回合意图 %s\n状态 %s" % [
		intent_name,
		_status_text(enemy),
	]
	pile_info.text = "手牌：%d  变身持有：%s" % [
		hand.size(),
		"1" if not held_transform_card.is_empty() else "0",
	]
	_refresh_pile_ui()
	battle_log.text = "\n".join(log_lines)
	_refresh_battle_log_visibility()
	end_turn_button.disabled = phase != "player"
	_refresh_hand()

func _refresh_unit_views() -> void:
	if player_unit_view != null:
		player_unit_view.refresh(player, player_magic_defense_bar_max)
	if enemy_unit_view != null:
		enemy_unit_view.refresh(enemy, enemy_magic_defense_bar_max)
		enemy_unit_view.set_intent(database.find_card(enemy_intent_card_id))

func _refresh_pile_ui() -> void:
	var draw_count := draw_pile.size()
	var has_draw_cards := draw_count > 0
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
	var hand_count: int = hand.size()
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
	for i in range(hand.size()):
		var card: Dictionary = database.find_card(str(hand[i].get("card_id", "")))
		var card_view = CardViewScene.instantiate()
		var can_play: bool = phase == "player" and player["magic"] >= _to_int(card.get("cost", 0))
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
		var rotation_degrees: float = normalized * max_rotation
		var arc_drop: float = abs_normalized * CARD_HAND_ARC_DROP
		var lift: float = CARD_PENDING_LIFT if is_pending else 0.0
		card_slot.position = Vector2(start_x + step * float(i), CARD_HAND_REST_Y + arc_drop - lift)
		card_slot.rotation_degrees = rotation_degrees
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

func _card_button_text(card: Dictionary) -> String:
	if card.is_empty():
		return "未知卡牌"
	return "%s  费:%s\n%s\n%s" % [
		str(card.get("name", "未知卡牌")),
		str(card.get("cost", 0)),
		_target_text(_to_int(card.get("target", 0))),
		_short_text(str(card.get("description", "")), 28),
	]

func _short_text(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length) + "..."

func _target_text(target: int) -> String:
	match target:
		TARGET_SELF:
			return "目标：自身"
		TARGET_SINGLE_ENEMY:
			return "目标：单个敌人"
		TARGET_PLAYER:
			return "目标：玩家"
		_:
			return "目标：无"

func _phase_text() -> String:
	match phase:
		"player":
			return "玩家回合"
		"enemy":
			return "敌人回合"
		"victory":
			return "战斗胜利"
		"defeat":
			return "战斗失败"
		_:
			return "准备中"

func _status_text(unit: Dictionary) -> String:
	var statuses: Array = unit.get("statuses", [])
	if statuses.is_empty():
		return "无"
	var parts: Array[String] = []
	for status in statuses:
		parts.append("%s x%s" % [status.get("name", "状态"), status.get("stack", 1)])
	return "，".join(parts)

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

func _to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	var text := str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes"

func _log(message: String) -> void:
	log_lines.append(message)
	while log_lines.size() > 12:
		log_lines.pop_front()
