extends RefCounted
class_name CorruptedStudentAI

func choose_action(context: Dictionary) -> String:
	var player_sensitivity := int(context.get("player_sensitivity", 0))

	if player_sensitivity < 20:
		return "card_enemy_hypnosis_ray"
	return "card_enemy_assault"
