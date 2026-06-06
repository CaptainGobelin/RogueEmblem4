extends Node2D
class_name UnitPawn

signal clicked(unit: UnitPawn)
signal died
signal acted

static var unitScene = preload("res://scenes/battle/UnitPawn.tscn")
static var INVALID: UnitPawn = null

@onready var button: Button = $Button

var entity: UnitManager
var previousPos: Vector2i
var pos: Vector2i
var hasActed: bool = false:
	set(value):
		hasActed = value
		if hasActed:
			$Body.modulate = Color.WEB_GRAY
			if entity.team == UnitManager.Team.PLAYER:
				acted.emit()
		else:
			$Body.modulate = Color.WHITE

func _ready() -> void:
	button.pressed.connect(_onPressed)

# ==============================================================================
# Public
# ==============================================================================

func wait() -> void:
	hasActed = true

func attack(target: UnitPawn) -> void:
	print(name + " attacks " + target.name)
	target.takeDamage(entity.getDamages())
	hasActed = true

func takeDamage(amount: int) -> void:
	entity.currentHp -= amount
	if entity.currentHp <= 0:
		entity.isDead = true
		print(entity.unitName + " dies !")
		Ref.map.occupiedCells.erase(pos)
		died.emit()
		get_parent().remove_child(self)
		queue_free()

func placeTo(cell: Vector2i) -> void:
	previousPos = cell
	pos = cell
	position = Data.CELL_SIZE * cell

func moveTo(cell: Vector2i) -> void:
	previousPos = pos
	pos = cell
	position = Data.CELL_SIZE * cell

# ==============================================================================
# Statics
# ==============================================================================

static func spawnPlayerUnit(e: UnitManager, cell: Vector2i) -> void:
	var unit := unitScene.instantiate()
	unit.entity = e
	Ref.map.placeUnit(unit, cell)
	Ref.units.add_child(unit)

static func spawnAIUnit(e: UnitManager, cell: Vector2i) -> void:
	var unit := unitScene.instantiate()
	unit.entity = e
	Ref.map.placeUnit(unit, cell)
	Ref.units.add_child(unit)

# ==============================================================================
# Events
# ==============================================================================

func _onPressed() -> void:
	clicked.emit(self)

func _onNewTurn(_turn: BattleManager.Turn) -> void:
	hasActed = false
