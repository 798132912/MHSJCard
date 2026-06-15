extends RefCounted
class_name CardZoneManager

const PLAY_DESTINATION_DISCARD := 20
const PLAY_DESTINATION_STATUS_HOLD := 30

var next_instance_id := 1
var draw_pile: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
var exhaust_pile: Array[Dictionary] = []
var held_transform_card := {}

func reset() -> void:
	next_instance_id = 1
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	held_transform_card = {}

func build_player_deck(database: GameDatabase, deck_id: String, unit_id: String) -> void:
	for row in database.get_deck_rows(deck_id, unit_id):
		var card_id := str(row.get("card_id", ""))
		var count := _to_int(row.get("count", 1))
		var card: Dictionary = database.find_card(card_id)
		if card.is_empty() or str(card.get("owner_type", "player")) == "enemy":
			continue
		for i in range(count):
			draw_pile.append(_new_card_instance(card_id))

func draw_cards(count: int, hand_limit: int) -> Array[String]:
	var logs: Array[String] = []
	for i in range(count):
		if hand.size() >= hand_limit:
			if not draw_pile.is_empty():
				discard_pile.append(draw_pile.pop_front())
			continue
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return logs
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
			logs.append("弃牌堆洗入抽牌堆。")
		hand.append(draw_pile.pop_front())
	return logs

func discard_hand() -> void:
	while not hand.is_empty():
		discard_pile.append(hand.pop_front())

func take_hand_card(hand_index: int) -> Dictionary:
	if not is_valid_hand_index(hand_index):
		return {}
	var instance := hand[hand_index]
	hand.remove_at(hand_index)
	return instance

func move_played_card_after_resolution(card: Dictionary, instance: Dictionary) -> void:
	var play_destination := _to_int(card.get("play_destination", PLAY_DESTINATION_DISCARD))
	match play_destination:
		PLAY_DESTINATION_STATUS_HOLD:
			held_transform_card = instance
		PLAY_DESTINATION_DISCARD:
			_move_played_card_to_default_pile(card, instance)
		_:
			_move_played_card_to_default_pile(card, instance)

func discard_held_transform_card() -> bool:
	if held_transform_card.is_empty():
		return false
	discard_pile.append(held_transform_card)
	held_transform_card = {}
	return true

func is_valid_hand_index(hand_index: int) -> bool:
	return hand_index >= 0 and hand_index < hand.size()

func hand_card_id(hand_index: int) -> String:
	if not is_valid_hand_index(hand_index):
		return ""
	return str(hand[hand_index].get("card_id", ""))

func has_held_transform_card() -> bool:
	return not held_transform_card.is_empty()

func hand_size() -> int:
	return hand.size()

func draw_pile_size() -> int:
	return draw_pile.size()

func _move_played_card_to_default_pile(card: Dictionary, instance: Dictionary) -> void:
	if _to_bool(card.get("exhaust", false)):
		exhaust_pile.append(instance)
	else:
		discard_pile.append(instance)

func _new_card_instance(card_id: String) -> Dictionary:
	var result := {
		"instance_id": next_instance_id,
		"card_id": card_id,
	}
	next_instance_id += 1
	return result

func _to_int(value: Variant) -> int:
	if value == null:
		return 0
	var text := str(value).strip_edges()
	if text == "" or text == "待定":
		return 0
	return int(text)

func _to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	var text := str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes"
