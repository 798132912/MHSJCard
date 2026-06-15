extends RefCounted
class_name EnemyAIController

var ai_impl

func setup(_ai_impl) -> void:
	ai_impl = _ai_impl

func choose_action(player: Dictionary, enemy: Dictionary, available_action_cards: Array[String]) -> String:
	if available_action_cards.is_empty():
		return ""

	var context := _build_context(player, enemy)
	var chosen := ""
	if ai_impl != null and ai_impl.has_method("choose_action"):
		chosen = str(ai_impl.choose_action(context))

	if not available_action_cards.has(chosen):
		chosen = available_action_cards[0]
	return chosen

func _build_context(player: Dictionary, enemy: Dictionary) -> Dictionary:
	return {
		"player_sensitivity": player.get("sensitivity", 0),
		"player_hp": player.get("hp", 0),
		"player_arousal": player.get("arousal", 0),
		"enemy_hp": enemy.get("hp", 0),
	}
