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
const RESOURCE_MASOCHISM_TENDENCY := 90
const RESOURCE_EXPOSURE_TENDENCY := 100
const RESOURCE_KISS_TENDENCY := 110
const RESOURCE_SEMEN := 120
const RESOURCE_CHEST_SENSITIVITY := 130
const RESOURCE_CLITORIS_SENSITIVITY := 140
const RESOURCE_WOMB_SENSITIVITY := 150
const RESOURCE_VAGINA_SENSITIVITY := 160
const RESOURCE_FIREPOWER := 170
const RESOURCE_SPIRIT := 180

const RESOURCE_FIELDS := {
	RESOURCE_MASOCHISM_TENDENCY: "masochism_tendency",
	RESOURCE_EXPOSURE_TENDENCY: "exposure_tendency",
	RESOURCE_KISS_TENDENCY: "kiss_tendency",
	RESOURCE_SEMEN: "semen",
	RESOURCE_CHEST_SENSITIVITY: "chest_sensitivity",
	RESOURCE_CLITORIS_SENSITIVITY: "clitoris_sensitivity",
	RESOURCE_WOMB_SENSITIVITY: "womb_sensitivity",
	RESOURCE_VAGINA_SENSITIVITY: "vagina_sensitivity",
	RESOURCE_FIREPOWER: "firepower",
	RESOURCE_SPIRIT: "spirit",
}

const RESOURCE_NAMES := {
	RESOURCE_MASOCHISM_TENDENCY: "受虐倾向",
	RESOURCE_EXPOSURE_TENDENCY: "暴露倾向",
	RESOURCE_KISS_TENDENCY: "接吻倾向",
	RESOURCE_SEMEN: "子宫精液含量",
	RESOURCE_CHEST_SENSITIVITY: "胸部敏感度",
	RESOURCE_CLITORIS_SENSITIVITY: "阴蒂敏感度",
	RESOURCE_WOMB_SENSITIVITY: "子宫敏感度",
	RESOURCE_VAGINA_SENSITIVITY: "小穴敏感度",
	RESOURCE_FIREPOWER: "火力",
	RESOURCE_SPIRIT: "灵力",
}

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
			target["magic"] = clampi(_to_int(target.get("magic", 0)) + amount, 0, _to_int(target.get("magic_max", 0)))
			result["logs"].append("%s 当前魔力变化 %+d。" % [target["name"], amount])
		RESOURCE_MAGIC_MAX:
			target["magic_max"] = _to_int(target.get("magic_max", 0)) + amount
			target["magic"] = min(_to_int(target.get("magic", 0)), _to_int(target.get("magic_max", 0)))
			result["logs"].append("%s 魔力上限变化 %+d。" % [target["name"], amount])
		RESOURCE_MAGIC_DEFENSE:
			target["magic_defense"] = max(0, _to_int(target.get("magic_defense", 0)) + amount)
			if target.get("unit_type", "") == "enemy":
				result["enemy_magic_defense_bar_candidate"] = _to_int(target["magic_defense"])
			else:
				result["player_magic_defense_bar_candidate"] = _to_int(target["magic_defense"])
			result["logs"].append("%s 魔力防御变化 %+d。" % [target["name"], amount])
		RESOURCE_MAGIC_SHIELD:
			var shield_gain := _calculate_magic_shield_delta(amount, target)
			target["magic_shield"] = max(0, _to_int(target.get("magic_shield", 0)) + shield_gain)
			if target.get("unit_type", "") == "enemy":
				result["enemy_magic_defense_bar_candidate"] = max(0, _to_int(target.get("magic_defense", 0)))
			result["logs"].append("%s 魔力护盾变化 %+d。" % [target["name"], shield_gain])
		RESOURCE_AROUSAL:
			var gained := _calculate_arousal_delta(amount, parts, target)
			target["arousal"] = clampi(_to_int(target.get("arousal", 0)) + gained, 0, _to_int(target.get("arousal_max", 100)))
			result["logs"].append("%s 发情值变化 %+d。" % [target["name"], gained])
		RESOURCE_SENSITIVITY:
			target["sensitivity"] = max(0, _to_int(target.get("sensitivity", 0)) + amount)
			result["logs"].append("%s 敏感值变化 %+d。" % [target["name"], amount])
		RESOURCE_CORRUPTION:
			target["corruption"] = max(0, _to_int(target.get("corruption", 0)) + amount)
			result["logs"].append("%s 堕落值变化 %+d。" % [target["name"], amount])
		_:
			if RESOURCE_FIELDS.has(resource_type):
				_apply_metric_change(resource_type, amount, target, result)
	return result

func _calculate_arousal_delta(amount: int, parts: Array[int], target: Dictionary) -> int:
	if amount <= 0:
		return amount
	var result := amount
	if parts.size() >= 3:
		var modifier_type := parts[2]
		var modifier_field := str(RESOURCE_FIELDS.get(modifier_type, ""))
		if modifier_field != "":
			result += floori(float(_to_int(target.get(modifier_field, 0))) / 10.0)
	result = ceili(float(result) * (1.0 + float(_to_int(target.get("sensitivity", 0))) / 100.0))
	return max(0, result)

func _apply_metric_change(resource_type: int, amount: int, target: Dictionary, result: Dictionary) -> void:
	var field := str(RESOURCE_FIELDS.get(resource_type, ""))
	var resource_name := str(RESOURCE_NAMES.get(resource_type, "状态数值"))
	if field == "":
		return
	target[field] = _to_int(target.get(field, 0)) + amount
	result["logs"].append("%s %s变化 %+d。" % [target["name"], resource_name, amount])

func _calculate_magic_shield_delta(amount: int, target: Dictionary) -> int:
	if amount <= 0:
		return amount
	return max(0, amount + _to_int(target.get("spirit", 0)))

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
