extends RefCounted

class_name UnitStateFactory

func create_player(character: Dictionary) -> Dictionary:
	var human_magic_max := _to_int(character.get("human_base_magic_max", 0))
	return {
		"id": str(character.get("id", "")),
		"name": str(character.get("name", "玩家")),
		"unit_type": str(character.get("unit_type", "player")),
		"max_hp": _to_int(character.get("max_hp", 30)),
		"hp": _to_int(character.get("max_hp", 30)),
		"base_draw_count": _to_int(character.get("base_draw_count", 5)),
		"base_hand_limit": _to_int(character.get("base_hand_limit", 10)),
		"human_base_magic_max": human_magic_max,
		"magic": human_magic_max,
		"magic_max": human_magic_max,
		"magic_shield": _to_int(character.get("init_magic_shield", 0)),
		"magic_defense": _to_int(character.get("init_magic_defense", 0)),
		"arousal": _to_int(character.get("init_arousal", 0)),
		"arousal_max": _to_int(character.get("arousal_max", 100)),
		"sensitivity": _to_int(character.get("init_sensitivity", 0)),
		"corruption": _to_int(character.get("init_corruption", 0)),
		"masochism_tendency": _to_int(character.get("init_masochism_tendency", 0)),
		"exposure_tendency": _to_int(character.get("init_exposure_tendency", 0)),
		"kiss_tendency": _to_int(character.get("init_kiss_tendency", 0)),
		"semen": _to_int(character.get("init_semen", 0)),
		"chest_sensitivity": _to_int(character.get("init_chest_sensitivity", 0)),
		"clitoris_sensitivity": _to_int(character.get("init_clitoris_sensitivity", 0)),
		"womb_sensitivity": _to_int(character.get("init_womb_sensitivity", 0)),
		"vagina_sensitivity": _to_int(character.get("init_vagina_sensitivity", 0)),
		"firepower": _to_int(character.get("init_firepower", 0)),
		"spirit": _to_int(character.get("init_spirit", 0)),
		"form": "人类形态",
		"transformed": false,
		"statuses": [],
		"battle_image_path": str(character.get("battle_image_path", "")),
		"portrait_path": str(character.get("portrait_path", "")),
		"hit_motion_profile": str(character.get("hit_motion_profile", "bump")),
	}

func create_enemy(enemy_row: Dictionary) -> Dictionary:
	return {
		"id": str(enemy_row.get("id", "")),
		"name": str(enemy_row.get("name", "敌人")),
		"unit_type": str(enemy_row.get("unit_type", "enemy")),
		"max_hp": _to_int(enemy_row.get("max_hp", 25)),
		"hp": _to_int(enemy_row.get("max_hp", 25)),
		"magic_shield": _to_int(enemy_row.get("init_magic_shield", 0)),
		"magic_defense": _to_int(enemy_row.get("init_magic_defense", 0)),
		"firepower": _to_int(enemy_row.get("init_firepower", 0)),
		"spirit": _to_int(enemy_row.get("init_spirit", 0)),
		"magic_defense_break_enabled": _to_int(enemy_row.get("init_magic_defense", 0)) > 0,
		"magic_defense_broken": false,
		"hidden_effect_ids": _effect_ids(enemy_row.get("hidden_effect_ids", "")),
		"stun_turns": 0,
		"statuses": [],
		"battle_image_path": str(enemy_row.get("battle_image_path", "")),
		"portrait_path": str(enemy_row.get("portrait_path", "")),
		"hit_motion_profile": str(enemy_row.get("hit_motion_profile", "bump")),
	}

func _effect_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for id in str(value).split(";", false):
		var text := id.strip_edges()
		if text != "":
			result.append(text)
	return result

func _to_int(value: Variant) -> int:
	if value == null:
		return 0
	var text := str(value).strip_edges()
	if text == "" or text == "待定":
		return 0
	return int(text)
