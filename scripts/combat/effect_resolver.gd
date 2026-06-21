extends RefCounted
class_name EffectResolver

const EFFECT_MODIFY_RESOURCE := 100
const EFFECT_DAMAGE := 200
const EFFECT_ATTACH_EFFECT := 300

var database
var select_target_callback: Callable
var apply_resource_effect_callback: Callable
var apply_damage_effect_callback: Callable
var apply_attach_effect_callback: Callable
var is_combat_over_callback: Callable
var log_callback: Callable

func setup(
	_database,
	_select_target_callback: Callable,
	_apply_resource_effect_callback: Callable,
	_apply_damage_effect_callback: Callable,
	_apply_attach_effect_callback: Callable,
	_is_combat_over_callback: Callable,
	_log_callback: Callable
) -> void:
	database = _database
	select_target_callback = _select_target_callback
	apply_resource_effect_callback = _apply_resource_effect_callback
	apply_damage_effect_callback = _apply_damage_effect_callback
	apply_attach_effect_callback = _apply_attach_effect_callback
	is_combat_over_callback = _is_combat_over_callback
	log_callback = _log_callback

func resolve_card(card: Dictionary, source_side: String, target_side: String = "") -> void:
	var effect_ids := str(card.get("effect_ids", "")).split(";", false)
	for effect_id in effect_ids:
		var effect: Dictionary = database.find_card_effect(effect_id)
		if effect.is_empty():
			_log("找不到效果 %s。" % effect_id)
			continue
		_resolve_effect(effect, card, source_side, target_side)
		if _is_combat_over():
			return

func resolve_standalone_effect(effect: Dictionary, source_side: String, target_side: String = "") -> void:
	_resolve_effect(effect, effect, source_side, target_side)

func _resolve_effect(effect: Dictionary, card: Dictionary, source_side: String, target_side: String = "") -> void:
	var target_rule := card.duplicate()
	if str(effect.get("target", "")).strip_edges() != "":
		target_rule["target"] = effect.get("target", card.get("target", 0))
	var target: Dictionary = select_target_callback.call(target_rule, source_side, target_side)
	if target.is_empty():
		return
	var effect_type := _to_int(effect.get("effect_type", 0))
	match effect_type:
		EFFECT_MODIFY_RESOURCE:
			apply_resource_effect_callback.call(effect, target)
		EFFECT_DAMAGE:
			apply_damage_effect_callback.call(effect, target, source_side)
		EFFECT_ATTACH_EFFECT:
			apply_attach_effect_callback.call(effect, target)
		_:
			_log("暂未支持效果类型 %s。" % effect_type)

func _is_combat_over() -> bool:
	if not is_combat_over_callback.is_valid():
		return false
	return bool(is_combat_over_callback.call())

func _log(message: String) -> void:
	if log_callback.is_valid():
		log_callback.call(message)

func _to_int(value: Variant) -> int:
	if value == null:
		return 0
	var text := str(value).strip_edges()
	if text == "" or text == "待定":
		return 0
	return int(text)
