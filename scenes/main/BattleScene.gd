extends Node2D
class_name BattleScene

@onready var map : BattleMap = $BattleMap
@onready var units : Node = $Units
@onready var inputManager : InputManager = $InputManager
@onready var battleManager : BattleManager = $BattleManager
@onready var aiManager: AIManager = $AIManager
@onready var camera: Camera2D = $MainCamera
@onready var ui: CanvasLayer = $UI

func _ready() -> void:
	Ref.units = units
	Ref.map = map
	Ref.camera = camera
	Ref.ui = ui
	inputManager.battleScene = self
	inputManager.registerMap(map)
	inputManager.registerBattleManager(battleManager)
	inputManager.registerUi(ui)
	initBattle()

func initBattle() -> void:
	battleManager.startBattle()

func askEnemyTurn() -> void:
	await aiManager.performEnemyTurn()
	battleManager.endTurn()

func askSelectUnit(unit : UnitPawn) -> void:
	if unit.team != UnitPawn.Team.PLAYER:
		return
	if unit.hasActed:
		return
	map.computeTacticalArea(unit)
	map.drawReach()
	inputManager.selectDestinationMode(unit)

func askApplyAction(unit: UnitPawn, action: Data.actions) -> void:
	match action:
		Data.actions.ATTACK:
			pass
		Data.actions.WAIT:
			askWait(unit)

func askAttack(attacker: UnitPawn, defender: UnitPawn, noMove: bool = false) -> void:
	if not map.currentAttackMap.has(defender.pos):
		return
	if defender.team != UnitPawn.Team.ENEMY:
		return
	if not noMove:
		map.moveUnit(attacker, map.currentAttackMap[defender.pos])
	attacker.attack(defender)
	inputManager.selectUnitMode()

func askMove(unit : UnitPawn, cell : Vector2i) -> void:
	if unit == null:
		return
	map.moveUnit(unit, cell)
	inputManager.chooseActionMode()

func askWait(unit: UnitPawn) -> void:
	Ref.map.clearMask()
	unit.wait()
	inputManager.selectUnitMode()

func checkEndPlayerTurn() -> void:
	for unit in units.get_children():
		if unit.team == UnitPawn.Team.PLAYER and not unit.hasActed:
			return
	battleManager.call_deferred("endTurn")

func _onUnitSpawned(unit: UnitPawn) -> void:
	inputManager.registerUnit(unit)
	battleManager.registerUnit(unit)
	unit.died.connect(battleManager.isBattleOver)
	unit.acted.connect(checkEndPlayerTurn)
