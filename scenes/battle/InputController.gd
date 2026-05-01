extends Node
class_name InputController

enum InputState {
	INPUT_SELECT_UNIT,
	INPUT_SELECT_DESTINATION,
	INPUT_SELECT_ACTION,
	INPUT_SELECT_TARGET,
	INPUT_LOCKED
}

@export var battle_scene : BattleScene

var state : InputState = InputState.INPUT_LOCKED
var selected_unit : Unit = null

func registerUnit(unit: Unit) -> void:
	unit.clicked.connect(_onUnitClicked)

func registerMap(map: BattleMap) -> void:
	map.cell_clicked.connect(_onCellClicked)

func registerTurnManager(turnManager: TurnManager) -> void:
	turnManager.turnStarted.connect(_onTurnStarted)
	turnManager.turnEnded.connect(_onTurnEnded)

func registerUi(ui: BattleUI) -> void:
	ui.actionMenu.attackClicked.connect(_onAttackActionClicked)
	ui.actionMenu.waitClicked.connect(_onWaitActionClicked)

# ==============================================================================
# Modes
# ==============================================================================

func lockInput() -> void:
	state = InputState.INPUT_LOCKED
	selected_unit = null
	Ref.map.clearMask()

func selectUnitMode() -> void:
	state = InputState.INPUT_SELECT_UNIT
	selected_unit = null
	Ref.map.clearMask()

func selectDestinationMode(unit : Unit) -> void:
	selected_unit = unit
	state = InputState.INPUT_SELECT_DESTINATION

func chooseActionMode() -> void:
	Ref.map.clearMask()
	Ref.ui.actionMenu.open(selected_unit)
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
				Ref.map.placeUnit(selected_unit, selected_unit.previousPos)
				Ref.ui.actionMenu.close()
				battle_scene.askSelectUnit(selected_unit)
				return
			InputState.INPUT_SELECT_TARGET:
				chooseActionMode()
				return

func _onUnitClicked(unit : Unit) -> void:
	match state:
		InputState.INPUT_SELECT_UNIT:
			battle_scene.askSelectUnit(unit)
			return
		InputState.INPUT_SELECT_DESTINATION:
			if unit == selected_unit:
				battle_scene.askMove(unit, unit.pos)
				return
			battle_scene.askAttack(selected_unit, unit)
			return
		InputState.INPUT_SELECT_TARGET:
			battle_scene.askAttack(selected_unit, unit, true)
			return

func _onCellClicked(cell : Vector2i) -> void:
	if state != InputState.INPUT_SELECT_DESTINATION:
		return
	battle_scene.askMove(selected_unit, cell)

func _onAttackActionClicked() -> void:
	state = InputState.INPUT_SELECT_TARGET
	Ref.ui.actionMenu.close()
	Ref.map.computeAttackArea(selected_unit)
	Ref.map.drawReach(true)

func _onWaitActionClicked() -> void:
	Ref.ui.actionMenu.close()
	battle_scene.askWait(selected_unit)

func _onTurnStarted(turn: TurnManager.Turn) -> void:
	if turn == TurnManager.Turn.PLAYER:
		set_process_input(true)
		selectUnitMode()
	elif turn == TurnManager.Turn.ENEMY:
		battle_scene.askEnemyTurn()

func _onTurnEnded(turn: TurnManager.Turn) -> void:
	if turn == TurnManager.Turn.PLAYER:
		lockInput()
