extends Node2D
class_name Unit

enum Team { PLAYER, ENEMY }
signal clicked(unit: Unit)
signal died
signal acted

static var unitScene = preload("res://scenes/battle/Unit.tscn")
static var INVALID: Unit = null

@onready var button: Button = $Button

var team: Team = Team.PLAYER: 
	set(value):
		team = value
		if team == Team.PLAYER:
			$Body.frame = 0
		else:
			$Body.frame = 1

var previousPos: Vector2i
var pos: Vector2i
var maxHp: int = 10
var attack_power: int = 3
var aim: int = 80
var def: int = 0
var strength: int = 2
var speed: int = 2
var move: int = 4
var atkRange: Vector2i = Vector2i(2, 2) # min, max
var hp: int
var isDead: bool = false
var has_acted: bool = false:
	set(value):
		has_acted = value
		if has_acted:
			$Body.modulate = Color.WEB_GRAY
			if team == Team.PLAYER:
				acted.emit()
		else:
			$Body.modulate = Color.WHITE

func _ready() -> void:
	hp = maxHp
	button.pressed.connect(_onPressed)

# ==============================================================================
# Public
# ==============================================================================

func wait() -> void:
	has_acted = true

func attack(target: Unit) -> void:
	print(name + " attacks " + target.name)
	target.takeDamage(attack_power)
	has_acted = true

func takeDamage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		isDead = true
		print(name + " dies !")
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

static func spawnPlayerUnit(cell: Vector2i) -> void:
	var unit := unitScene.instantiate()
	unit.team = Team.PLAYER
	Ref.map.placeUnit(unit, cell)
	Ref.units.add_child(unit)

static func spawnAIUnit(cell: Vector2i, t: Team) -> void:
	var unit := unitScene.instantiate()
	unit.team = t
	Ref.map.placeUnit(unit, cell)
	Ref.units.add_child(unit)

# ==============================================================================
# Events
# ==============================================================================

func _onPressed() -> void:
	clicked.emit(self)

func _onNewTurn(_turn: TurnManager.Turn) -> void:
	has_acted = false
