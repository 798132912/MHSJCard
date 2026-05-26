extends RefCounted
class_name CorruptedStudentAI

func choose_action(context: Dictionary) -> String:
	var enemy_shield := int(context.get("enemy_magic_shield", 0))
	var player_sensitivity := int(context.get("player_sensitivity", 0))

	if enemy_shield <= 0:
		return "card_enemy_miasma_shield"
	if player_sensitivity < 20:
		return "card_enemy_hypnosis_ray"
	return "card_enemy_assault"
