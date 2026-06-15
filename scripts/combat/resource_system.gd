extends RefCounted
class_name ResourceSystem

const RESOURCE_HP := 10
const RESOURCE_MAGIC := 20
const RESOURCE_MAGIC_MAX := 30
const RESOURCE_MAGIC_DEFENSE := 40
const RESOURCE_MAGIC_SHIELD := 50
const RESOURCE_AROUSAL := 60
const RESOURCE_SENSITIVITY := 70
const RESOURCE_CORRUPTION := 80

func apply_resource_effect(effect: Dictionary, target: Dictionary, player: Dictionary) -> Dictionary:
	var result := {
		"logs": [],
		"player_magic_defense_bar_candidate": -1,
		"enemy_magic_defense_bar_candidate": -1,
	}
	var parts := _parse_value(effect.get("value", ""))
	if parts.size() < 2:
		return result

	var resource_type := parts[0]
	var amount := parts[1]
	match resource_type:
		RESOURCE_HP:
			target["hp"] = clampi(_to_int(target.get("hp", 0)) + amount, 0, _to_int(target.get("max_hp", 0)))
			result["logs"].append("%s 生命值变化 %+d。" % [target["name"], amount])
		RESOURCE_MAGIC:
			player["magic"] = clampi(player["magic"] + amount, 0, player["magic_max"])
			result["logs"].append("玩家获得 %d 点当前魔力。" % amount)
		RESOURCE_MAGIC_MAX:
			player["magic_max"] += amount
			player["magic"] = min(player["magic"], player["magic_max"])
			result["logs"].append("玩家魔力上限 %+d。" % amount)
		RESOURCE_MAGIC_DEFENSE:
			player["magic_defense"] = max(0, player["magic_defense"] + amount)
			result["player_magic_defense_bar_candidate"] = _to_int(player["magic_defense"])
			result["logs"].append("玩家获得 %d 点魔力防御。" % amount)
		RESOURCE_MAGIC_SHIELD:
			target["magic_shield"] = max(0, _to_int(target.get("magic_shield", 0)) + amount)
			if target.get("unit_type", "") == "enemy":
				result["enemy_magic_defense_bar_candidate"] = max(0, _to_int(target.get("magic_defense", 0)))
			result["logs"].append("%s 获得 %d 点魔力护盾。" % [target["name"], amount])
		RESOURCE_AROUSAL:
			var gained := ceili(float(amount) * (1.0 + float(player["sensitivity"]) / 100.0))
			player["arousal"] = clampi(player["arousal"] + gained, 0, player["arousal_max"])
			result["logs"].append("玩家发情值提升 %d。" % gained)
		RESOURCE_SENSITIVITY:
			player["sensitivity"] = max(0, player["sensitivity"] + amount)
			result["logs"].append("玩家敏感值提升 %d。" % amount)
		RESOURCE_CORRUPTION:
			player["corruption"] = max(0, player["corruption"] + amount)
			result["logs"].append("玩家堕落值提升 %d。" % amount)
	return result

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
