extends Node
class_name GameDatabase

const TableLoaderScript = preload("res://scripts/core/table_loader.gd")

const CHARACTER_TABLE := "res://data/tables/Character.csv"
const CARD_TABLE := "res://data/tables/Card.csv"
const STARTER_DECK_TABLE := "res://data/tables/StarterDeck.csv"
const ENEMY_TABLE := "res://data/tables/Enemy.csv"
const ENEMY_ACTION_TABLE := "res://data/tables/EnemyAction.csv"
const CARD_EFFECT_TABLE := "res://data/tables/CardEffect.csv"
const CARD_POOL_TABLE := "res://data/tables/CardPool.csv"
const ENEMY_AI_TABLE := "res://data/tables/EnemyAI.csv"
const ITEM_TABLE := "res://data/tables/Item.csv"
const GAME_CONFIG_TABLE := "res://data/tables/GameConfig.csv"
const RESOURCE_CONFIG_TABLE := "res://data/tables/ResourceConfig.csv"
const DAMAGE_TYPE_CONFIG_TABLE := "res://data/tables/DamageTypeConfig.csv"
const STATUS_CONFIG_TABLE := "res://data/tables/StatusConfig.csv"
const FORM_CONFIG_TABLE := "res://data/tables/FormConfig.csv"
const PILE_CONFIG_TABLE := "res://data/tables/PileConfig.csv"
const TURN_PHASE_CONFIG_TABLE := "res://data/tables/TurnPhaseConfig.csv"
const TARGET_TYPE_CONFIG_TABLE := "res://data/tables/TargetTypeConfig.csv"
const CARD_TYPE_CONFIG_TABLE := "res://data/tables/CardTypeConfig.csv"
const ENEMY_INTENT_CONFIG_TABLE := "res://data/tables/EnemyIntentConfig.csv"

var characters: Array[Dictionary] = []
var cards: Array[Dictionary] = []
var starter_decks: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var enemy_actions: Array[Dictionary] = []
var card_effects: Array[Dictionary] = []
var card_pools: Array[Dictionary] = []
var enemy_ai_rules: Array[Dictionary] = []
var items: Array[Dictionary] = []
var game_configs: Array[Dictionary] = []
var resource_configs: Array[Dictionary] = []
var damage_type_configs: Array[Dictionary] = []
var status_configs: Array[Dictionary] = []
var form_configs: Array[Dictionary] = []
var pile_configs: Array[Dictionary] = []
var turn_phase_configs: Array[Dictionary] = []
var target_type_configs: Array[Dictionary] = []
var card_type_configs: Array[Dictionary] = []
var enemy_intent_configs: Array[Dictionary] = []

func load_all() -> void:
	characters = TableLoaderScript.load_csv(CHARACTER_TABLE)
	cards = TableLoaderScript.load_csv(CARD_TABLE)
	starter_decks = TableLoaderScript.load_csv(STARTER_DECK_TABLE)
	enemies = TableLoaderScript.load_csv(ENEMY_TABLE)
	enemy_actions = TableLoaderScript.load_csv(ENEMY_ACTION_TABLE)
	card_effects = TableLoaderScript.load_csv(CARD_EFFECT_TABLE)
	card_pools = TableLoaderScript.load_csv(CARD_POOL_TABLE)
	enemy_ai_rules = TableLoaderScript.load_csv(ENEMY_AI_TABLE)
	items = TableLoaderScript.load_csv(ITEM_TABLE)
	game_configs = TableLoaderScript.load_csv(GAME_CONFIG_TABLE)
	resource_configs = TableLoaderScript.load_csv(RESOURCE_CONFIG_TABLE)
	damage_type_configs = TableLoaderScript.load_csv(DAMAGE_TYPE_CONFIG_TABLE)
	status_configs = TableLoaderScript.load_csv(STATUS_CONFIG_TABLE)
	form_configs = TableLoaderScript.load_csv(FORM_CONFIG_TABLE)
	pile_configs = TableLoaderScript.load_csv(PILE_CONFIG_TABLE)
	turn_phase_configs = TableLoaderScript.load_csv(TURN_PHASE_CONFIG_TABLE)
	target_type_configs = TableLoaderScript.load_csv(TARGET_TYPE_CONFIG_TABLE)
	card_type_configs = TableLoaderScript.load_csv(CARD_TYPE_CONFIG_TABLE)
	enemy_intent_configs = TableLoaderScript.load_csv(ENEMY_INTENT_CONFIG_TABLE)

func find_by_id(rows: Array[Dictionary], id_column: String, id_value: String) -> Dictionary:
	for row in rows:
		if str(row.get(id_column, "")) == id_value:
			return row
	return {}

func find_card(card_id: String) -> Dictionary:
	return find_by_id(cards, "id", card_id)

func find_card_effect(effect_id: String) -> Dictionary:
	return find_by_id(card_effects, "id", effect_id)

func get_deck_rows(deck_id: String, unit_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in starter_decks:
		if str(row.get("deck_id", "")) != deck_id:
			continue
		if unit_id != "" and str(row.get("unit_id", "")) != unit_id:
			continue
		result.append(row)
	return result
