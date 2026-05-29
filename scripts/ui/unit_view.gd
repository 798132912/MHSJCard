extends Control
class_name UnitView

@onready var intent_label: Label = $IntentLabel
@onready var intent_art: TextureRect = $IntentArt
@onready var name_label: Label = $NameLabel
@onready var unit_texture: TextureRect = $ImageArea/Texture
@onready var placeholder: ColorRect = $ImageArea/Placeholder
@onready var health_bar: Control = $Bars/HealthBar
@onready var health_empty: TextureRect = $Bars/HealthBar/Empty
@onready var health_full_clip: Control = $Bars/HealthBar/FullClip
@onready var health_full: TextureRect = $Bars/HealthBar/FullClip/Full
@onready var health_value_label: Label = $Bars/HealthBar/HealthValueLabel
@onready var magic_defense_bar: Control = $Bars/MagicDefenseBar
@onready var magic_defense_empty: TextureRect = $Bars/MagicDefenseBar/Empty
@onready var magic_defense_full_clip: Control = $Bars/MagicDefenseBar/FullClip
@onready var magic_defense_full: TextureRect = $Bars/MagicDefenseBar/FullClip/Full
@onready var magic_defense_value_label: Label = $Bars/MagicDefenseBar/MagicDefenseValueLabel

var _is_enemy := false

func setup(unit: Dictionary, is_enemy: bool, defense_max: int = 1) -> void:
	_is_enemy = is_enemy
	intent_label.visible = is_enemy
	intent_art.visible = false
	refresh(unit, defense_max)

func refresh(unit: Dictionary, defense_max: int = 1) -> void:
	name_label.text = str(unit.get("name", "单位"))
	_load_unit_image(str(unit.get("battle_image_path", "")))
	_refresh_health(unit)
	_refresh_magic_defense(unit, defense_max)

func set_intent(card: Dictionary) -> void:
	if not _is_enemy:
		return
	var intent_name := str(card.get("name", "无")) if not card.is_empty() else "无"
	intent_label.text = "意图：%s" % intent_name
	_load_texture_from_path(intent_art, str(card.get("art_path", "")))

func _refresh_health(unit: Dictionary) -> void:
	var max_hp: int = max(1, _to_int(unit.get("max_hp", 1)))
	var hp: int = clampi(_to_int(unit.get("hp", 0)), 0, max_hp)
	_set_resource_bar_ratio(health_bar, health_full_clip, health_full, float(hp) / float(max_hp))
	health_value_label.text = "%d/%d" % [hp, max_hp]

func _refresh_magic_defense(unit: Dictionary, defense_max: int) -> void:
	var defense := _unit_magic_defense(unit)
	var should_show := defense > 0
	magic_defense_bar.visible = should_show
	magic_defense_value_label.visible = should_show
	if not should_show:
		return

	var max_value: int = max(1, defense_max, defense)
	_set_resource_bar_ratio(magic_defense_bar, magic_defense_full_clip, magic_defense_full, float(defense) / float(max_value))
	magic_defense_value_label.text = "%d/%d" % [defense, max_value]

func _unit_magic_defense(unit: Dictionary) -> int:
	if unit.has("magic_defense"):
		return max(0, _to_int(unit.get("magic_defense", 0)))
	return max(0, _to_int(unit.get("magic_shield", 0)))

func _set_resource_bar_ratio(bar: Control, full_clip: Control, full_texture: TextureRect, ratio: float) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var bar_size := bar.size
	full_texture.size = bar_size
	full_clip.size = Vector2(bar_size.x * clamped_ratio, bar_size.y)

func _load_unit_image(path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		unit_texture.texture = load(path)
		unit_texture.visible = true
		placeholder.visible = false
	else:
		unit_texture.texture = null
		unit_texture.visible = false
		placeholder.visible = true

func _load_texture_from_path(texture_rect: TextureRect, path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		texture_rect.texture = load(path)
		texture_rect.visible = true
	else:
		texture_rect.texture = null
		texture_rect.visible = false

func _to_int(value: Variant) -> int:
	if value == null:
		return 0
	var text := str(value).strip_edges()
	if text == "" or text == "待定":
		return 0
	return int(text)
