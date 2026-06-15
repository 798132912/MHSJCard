extends RefCounted
class_name TargetResolver

const TARGET_SELF := 1
const TARGET_SINGLE_ENEMY := 2
const TARGET_ALL_ENEMIES := 3

func select_target(card: Dictionary, source_side: String, target_side: String, player: Dictionary, enemy: Dictionary) -> Dictionary:
	var target_type := _to_int(card.get("target", TARGET_SELF))
	if target_type == TARGET_SELF:
		return unit_for_side(source_side, player, enemy)
	if target_type == TARGET_SINGLE_ENEMY or target_type == TARGET_ALL_ENEMIES:
		return unit_for_side(target_side if target_side != "" else opponent_side(source_side), player, enemy)
	return {}

func is_valid_target_for_card(card: Dictionary, target_side: String, source_side: String = "player") -> bool:
	if card.is_empty():
		return false
	var target_type := _to_int(card.get("target", TARGET_SELF))
	if target_type == TARGET_SELF:
		return target_side == source_side
	if target_type == TARGET_SINGLE_ENEMY or target_type == TARGET_ALL_ENEMIES:
		return target_side == opponent_side(source_side)
	return false

func unit_for_side(side: String, player: Dictionary, enemy: Dictionary) -> Dictionary:
	if side == "enemy":
		return enemy
	if side == "player":
		return player
	return {}

func opponent_side(source_side: String) -> String:
	return "player" if source_side == "enemy" else "enemy"

func target_type(card: Dictionary) -> int:
	return _to_int(card.get("target", TARGET_SELF))

func is_self_target(card: Dictionary) -> bool:
	return target_type(card) == TARGET_SELF

func target_text(target: int) -> String:
	match target:
		TARGET_SELF:
			return "目标：自身"
		TARGET_SINGLE_ENEMY:
			return "目标：单个敌人"
		TARGET_ALL_ENEMIES:
			return "目标：敌方群体"
		_:
			return "目标：无"

func _to_int(value: Variant) -> int:
	if value == null:
		return 0
	var text := str(value).strip_edges()
	if text == "" or text == "待定":
		return 0
	return int(text)
