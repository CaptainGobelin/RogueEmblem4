extends Node
class_name InputManager

enum InputState {
	INPUT_SELECT_UNIT,
	INPUT_SELECT_DESTINATION,
	INPUT_SELECT_ACTION,
	INPUT_SELECT_TARGET,
	INPUT_LOCKED
}

var battleScene : BattleScene
var state : InputState = InputState.INPUT_LOCKED
var selectedUnit : Unit = null

func registerUnit(unit: Unit) -> void:
	unit.clicked.connect(_onUnitClicked)

func registerMap(map: BattleMap) -> void:
	map.cellClicked.connect(_onCellClicked)

func registerBattleManager(battleManager: BattleManager) -> void:
	battleManager.turnStarted.connect(_onTurnStarted)
	battleManager.turnEnded.connect(_onTurnEnded)

func registerUi(ui: BattleUI) -> void:
	ui.actionMenu.attackClicked.connect(_onAttackActionClicked)
	ui.actionMenu.waitClicked.connect(_onWaitActionClicked)

# ==============================================================================
# Modes
# ==============================================================================

func lockInput() -> void:
	state = InputState.INPUT_LOCKED
	selectedUnit = null
	Ref.map.clearMask()

func selectUnitMode() -> void:
	state = InputState.INPUT_SELECT_UNIT
	selectedUnit = null
	Ref.map.clearMask()

func selectDestinationMode(unit : Unit) -> void:
	selectedUnit = unit
	state = InputState.INPUT_SELECT_DESTINATION

func chooseActionMode() -> void:
	Ref.map.clearMask()
	Ref.ui.actionMenu.open(selectedUnit)
	state = InputState.INPUT_SELECT_ACTION

# ==============================================================================
# Events
# ==============================================================================

func _input(event: InputEvent) -> void:
	if state == InputState.INPUT_LOCKED:
		return
	if event.is_action_released("ui_cancel"):
		match state:
			InputState.INPUT_SELECT_DESTINATION:
				selectUnitMode()
				return
			InputState.INPUT_SELECT_ACTION:
				Ref.map.placeUnit(selectedUnit, selectedUnit.previousPos)
				Ref.ui.actionMenu.close()
				battleScene.askSelectUnit(selectedUnit)
				return
			InputState.INPUT_SELECT_TARGET:
				chooseActionMode()
				return

func _onUnitClicked(unit : Unit) -> void:
	match state:
		InputState.INPUT_SELECT_UNIT:
			battleScene.askSelectUnit(unit)
			return
		InputState.INPUT_SELECT_DESTINATION:
			if unit == selectedUnit:
				battleScene.askMove(unit, unit.pos)
				return
			battleScene.askAttack(selectedUnit, unit)
			return
		InputState.INPUT_SELECT_TARGET:
			battleScene.askAttack(selectedUnit, unit, true)
			return

func _onCellClicked(cell : Vector2i) -> void:
	if state != InputState.INPUT_SELECT_DESTINATION:
		return
	battleScene.askMove(selectedUnit, cell)

func _onAttackActionClicked() -> void:
	state = InputState.INPUT_SELECT_TARGET
	Ref.ui.actionMenu.close()
	Ref.map.computeAttackArea(selectedUnit)
	Ref.map.drawReach(true)

func _onWaitActionClicked() -> void:
	Ref.ui.actionMenu.close()
	battleScene.askWait(selectedUnit)

func _onTurnStarted(turn: BattleManager.Turn) -> void:
	if turn == BattleManager.Turn.PLAYER:
		set_process_input(true)
		selectUnitMode()
	elif turn == BattleManager.Turn.ENEMY:
		await battleScene.askEnemyTurn()

func _onTurnEnded(turn: BattleManager.Turn) -> void:
	if turn == BattleManager.Turn.PLAYER:
		lockInput()
