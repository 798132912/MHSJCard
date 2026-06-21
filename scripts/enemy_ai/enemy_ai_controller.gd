extends RefCounted
class_name EnemyAIController

var ai_impl

func setup(_ai_impl) -> void:
	ai_impl = _ai_impl

func choose_action(player: Dictionary, enemy: Dictionary, available_action_cards: Array[String]) -> String:
	if available_action_cards.is_empty():
		return ""

	var context := _build_context(player, enemy, available_action_cards)
	var chosen := ""
	if ai_impl != null and ai_impl.has_method("choose_action"):
		chosen = str(ai_impl.choose_action(context))

	if not available_action_cards.has(chosen):
		chosen = available_action_cards[0]
	return chosen

func _build_context(player: Dictionary, enemy: Dictionary, available_action_cards: Array[String]) -> Dictionary:
	return {
		"available_action_cards": available_action_cards.duplicate(),
		"player_sensitivity": player.get("sensitivity", 0),
		"player_exposure_tendency": player.get("exposure_tendency", 0),
		"player_hp": player.get("hp", 0),
		"player_arousal": player.get("arousal", 0),
		"enemy_hp": enemy.get("hp", 0),
		"enemy_max_hp": enemy.get("max_hp", 0),
		"enemy_magic_shield": enemy.get("magic_shield", 0),
		"enemy_magic_defense": enemy.get("magic_defense", 0),
		"enemy_magic_defense_broken": enemy.get("magic_defense_broken", false),
		"enemy_firepower": enemy.get("firepower", 0),
	}
