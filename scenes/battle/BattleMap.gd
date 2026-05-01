extends Node2D
class_name BattleMap

enum CellStatus {BLOCKED, VISIBLE, PASSABLE, FREE}

@onready var mapGenerator: MapGenerator = $MapGenerator
@onready var terrain: TileMapLayer = $Terrain
@onready var mask: TileMapLayer = $Mask
@onready var mapButton: Button = $Button

signal cell_clicked(cell : Vector2i)

var occupiedCells: Dictionary[Vector2i, Unit] = {}
var player_deploy_cells: Array[Vector2i] = []
var enemy_deploy_cells: Array[Vector2i] = []
var currentMoveMap: Dictionary[Vector2i, TacticalQuery.Path] = {}
var currentAttackMap: Dictionary[Vector2i, Vector2i] = {} # targetCell -> standCell

func _ready() -> void:
	mapButton.pressed.connect(_onMapPressed)

func initMap() -> void:
	mapGenerator.initTestMap(self)

func deployUnits() -> void:
	for cell in player_deploy_cells:
		Unit.spawnPlayerUnit(cell)
	for cell in enemy_deploy_cells:
		Unit.spawnAIUnit(cell, Unit.Team.ENEMY)

func placeUnit(unit: Unit, cell: Vector2i) -> void:
	occupiedCells.erase(unit.pos)
	unit.placeTo(cell)
	occupiedCells[cell] = unit

func moveUnit(unit: Unit, cell: Vector2i) -> void:
	if not currentMoveMap.has(cell):
		return
	occupiedCells.erase(unit.pos)
	unit.moveTo(cell)
	occupiedCells[cell] = unit

func computeTacticalArea(unit: Unit) -> void:
	currentMoveMap = $TacticalQuery.computeMoveMap(unit)
	currentAttackMap = $TacticalQuery.computeAttackMap(unit, currentMoveMap.keys())

func computeAttackArea(unit: Unit) -> void:
	currentAttackMap = $TacticalQuery.computeAttackMap(unit, [unit.pos])

func getUnitReach(unit: Unit) -> Dictionary[Vector2i, TacticalQuery.Path]:
	return $TacticalQuery.computeMoveMap(unit)

func getAttackableUnits(unit: Unit, cell: Vector2i) -> Array[Unit]:
	var result: Array[Unit] = []
	var attackMap = $TacticalQuery.computeAttackMap(unit, [cell] as Array[Vector2i])
	for a in attackMap.keys():
		var target: Unit = Ref.map.getCellUnit(a)
		if target == null or target == unit:
			continue
		if target.team == unit.team:
			continue
		result.append(target)
	return result

func clearMask():
	mask.clear()

func drawReach(ignoreMove: bool = false):
	clearMask()
	for a in currentAttackMap.keys():
		mask.set_cell(a, 0, Vector2i(1, 0))
	if ignoreMove:
		return
	for c in currentMoveMap.keys():
		mask.set_cell(c, 0, Vector2i(3, 0))

func isCellPassable(unit: Unit, cell: Vector2i) -> bool:
	return _getCellStatus(unit, cell) >= CellStatus.PASSABLE

func isCellFree(unit: Unit, cell: Vector2i) -> bool:
	return _getCellStatus(unit, cell) >= CellStatus.FREE

func getCellUnit(cell: Vector2i) -> Unit:
	return occupiedCells.get(cell, Unit.INVALID)

func _getCellStatus(unit: Unit, cell: Vector2i) -> CellStatus:
	if terrain.get_cell_source_id(cell) == -1:
		return CellStatus.BLOCKED
	if terrain.get_cell_atlas_coords(cell) == Vector2i(1, 0):
		return CellStatus.BLOCKED
	var occupator = getCellUnit(cell)
	if occupator == null or occupator == unit:
		return CellStatus.FREE
	if occupator.team != unit.team:
		return CellStatus.BLOCKED
	return CellStatus.PASSABLE

func _onMapPressed() -> void:
	var local_pos = get_local_mouse_position()
	var cell = terrain.local_to_map(local_pos)
	cell_clicked.emit(cell)
