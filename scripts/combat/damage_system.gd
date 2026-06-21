extends RefCounted
class_name DamageSystem

const DAMAGE_PIERCE := 40
const DAMAGE_TRUE := 50
const DAMAGE_SHIELD_BREAK := 60

func apply_damage_effect(effect: Dictionary, target: Dictionary, source_side: String, player: Dictionary, enemy: Dictionary = {}) -> Dictionary:
	var result := {
		"logs": [],
		"animate_hit": false,
	}
	var parts := _parse_value(effect.get("value", ""))
	if parts.size() < 2:
		return result

	var damage_type := parts[0]
	var amount := _calculate_damage(parts[1], damage_type, source_side, player, enemy)
	var remaining := amount

	if damage_type == DAMAGE_SHIELD_BREAK:
		var shield_loss: int = min(_to_int(target.get("magic_shield", 0)), remaining)
		target["magic_shield"] -= shield_loss
		result["logs"].append("%s 的魔力护盾被破坏 %d 点。" % [target["name"], shield_loss])
		return result

	if damage_type != DAMAGE_TRUE and damage_type != DAMAGE_PIERCE:
		var shield_loss: int = min(_to_int(target.get("magic_shield", 0)), remaining)
		target["magic_shield"] -= shield_loss
		remaining -= shield_loss

	if damage_type != DAMAGE_TRUE and target.has("magic_defense"):
		var defense_loss: int = min(_to_int(target.get("magic_defense", 0)), remaining)
		target["magic_defense"] -= defense_loss
		remaining -= defense_loss

	target["hp"] = max(0, _to_int(target.get("hp", 0)) - remaining)
	result["logs"].append("%s 受到 %d 点伤害。" % [target["name"], amount])
	result["animate_hit"] = true
	return result

func _calculate_damage(base_amount: int, damage_type: int, source_side: String, player: Dictionary, enemy: Dictionary) -> int:
	var result := base_amount
	if damage_type != DAMAGE_SHIELD_BREAK:
		result += _source_firepower(source_side, player, enemy)
	return max(0, result)

func _source_firepower(source_side: String, player: Dictionary, enemy: Dictionary) -> int:
	var source := player if source_side == "player" else enemy
	return _to_int(source.get("firepower", 0))

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
