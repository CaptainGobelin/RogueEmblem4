extends Node2D
class_name BattleScene

const unitScene = preload("res://scenes/battle/Unit.tscn")

@onready var map : BattleMap = $BattleMap
@onready var units : Node = $Units
@onready var input_controller : InputController = $InputController
@onready var turn_manager : TurnManager = $TurnManager
@onready var battle_manager : BattleManager = $BattleManager
@onready var aiManager: AIManager = $AIManager
@onready var camera: Camera2D = $MainCamera
@onready var ui: CanvasLayer = $UI

func _ready() -> void:
	Ref.units = units
	Ref.map = map
	Ref.camera = camera
	Ref.ui = ui
	battle_manager.units = units
	input_controller.battle_scene = self
	input_controller.registerMap(map)
	input_controller.registerTurnManager(turn_manager)
	input_controller.registerUi(ui)
	initBattle()

func initBattle() -> void:
	map.initMap()
	map.deployUnits()
	turn_manager.startBattle()

func askEnemyTurn() -> void:
	await aiManager.performEnemyTurn()
	battle_manager.isBattleOver()
	turn_manager.endTurn()

func askSelectUnit(unit : Unit) -> void:
	if unit.team != Unit.Team.PLAYER:
		return
	if unit.has_acted:
		return
	map.computeTacticalArea(unit)
	map.drawReach()
	input_controller.selectDestinationMode(unit)

func askApplyAction(unit: Unit, action: Data.actions) -> void:
	match action:
		Data.actions.ATTACK:
			pass
		Data.actions.WAIT:
			askWait(unit)

func askAttack(attacker: Unit, defender: Unit, noMove: bool = false) -> void:
	if not map.attackMap.has(defender.pos):
		return
	if defender.team != Unit.Team.ENEMY:
		return
	if not noMove:
		map.moveUnit(attacker, map.attackMap[defender.pos])
	attacker.attack(defender)
	input_controller.selectUnitMode()
	end_player_turn_if_needed()

func askMove(unit : Unit, cell : Vector2i) -> void:
	if unit == null:
		return
	map.moveUnit(unit, cell)
	input_controller.chooseActionMode()

func askWait(unit: Unit) -> void:
	Ref.map.clearMask()
	unit.has_acted = true
	input_controller.selectUnitMode()
	end_player_turn_if_needed()

func end_player_turn_if_needed() -> void:
	for unit in units.get_children():
		if unit is Unit and unit.team == Unit.Team.PLAYER and not unit.has_acted:
			return
	turn_manager.endTurn()

func _onUnitSpawned(unit: Unit) -> void:
	input_controller.registerUnit(unit)
	turn_manager.registerUnit(unit)
