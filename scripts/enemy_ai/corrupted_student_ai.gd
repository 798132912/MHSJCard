extends RefCounted
class_name CorruptedStudentAI

var next_action_index := 0

const NORMAL_ACTION_SEQUENCE := [
	"card_enemy_assault",
	"card_enemy_miasma_shield",
	"card_enemy_peek",
]

const BROKEN_ACTION_SEQUENCE := [
	"card_enemy_weak_assault",
]

func choose_action(context: Dictionary) -> String:
	var available_actions: Array = context.get("available_action_cards", [])
	if available_actions.is_empty():
		return ""
	if bool(context.get("enemy_magic_defense_broken", false)) or int(context.get("enemy_magic_defense", 0)) <= 0:
		return _first_available(BROKEN_ACTION_SEQUENCE, available_actions)
	return _next_sequence_action(available_actions)

func _next_sequence_action(available_actions: Array) -> String:
	for i in range(NORMAL_ACTION_SEQUENCE.size()):
		var action_id := str(NORMAL_ACTION_SEQUENCE[next_action_index % NORMAL_ACTION_SEQUENCE.size()])
		next_action_index += 1
		if available_actions.has(action_id):
			return action_id
	return str(available_actions[0])

func _first_available(sequence: Array, available_actions: Array) -> String:
	for action_id in sequence:
		if available_actions.has(action_id):
			return str(action_id)
	return str(available_actions[0])
