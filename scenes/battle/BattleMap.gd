extends Node2D
class_name BattleMap

@onready var mapGenerator: MapGenerator = $MapGenerator
@onready var terrain: TileMapLayer = $Terrain
@onready var mask: TileMapLayer = $Mask
@onready var mapButton: Button = $Button

signal cell_clicked(cell : Vector2i)

var occupiedCells: Dictionary[Unit, Vector2i] = {}
var player_deploy_cells: Array[Vector2i] = []
var enemy_deploy_cells: Array[Vector2i] = []
var currentReach: Dictionary[Vector2i, TacticalQuery.Path] = {}
var attackMap: Dictionary[Vector2i, Vector2i] = {} # targetCell -> standCell

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
	unit.moveTo(cell)
	occupiedCells[unit] = cell

func moveUnit(unit: Unit, cell: Vector2i) -> void:
	if not currentReach.has(cell):
		return
	unit.moveTo(cell)
	occupiedCells[unit] = cell

func getUnitReach(unit: Unit):
	$TacticalQuery.computeTacticalAreas(unit)
	return currentReach

func getUnitTargets(unit: Unit) -> void:
	$TacticalQuery.getTargetableArea(unit)

func getAttackableUnits(unit: Unit, cell: Vector2i):
	return $TacticalQuery.getAttackableUnits(unit, cell)

func clearMask():
	mask.clear()

func drawReach():
	clearMask()
	for a in attackMap.keys():
		mask.set_cell(a, 0, Vector2i(1, 0))
	for c in currentReach.keys():
		mask.set_cell(c, 0, Vector2i(3, 0))

func isCellPassable(unit: Unit, cell: Vector2i) -> bool:
	if terrain.get_cell_source_id(cell) == -1:
		return false
	if terrain.get_cell_atlas_coords(cell) == Vector2i(1, 0):
		return false
	var occupator = getCellUnit(cell)
	if occupator != null and occupator != unit:
		if occupator.team != unit.team:
			return false
	return true

func isCellFree(unit: Unit, cell: Vector2i) -> bool:
	if terrain.get_cell_source_id(cell) == -1:
		return false
	if terrain.get_cell_atlas_coords(cell) == Vector2i(1, 0):
		return false
	var occupator = getCellUnit(cell)
	if occupator != null and occupator != unit:
		return false
	return true

func getCellUnit(cell: Vector2i) -> Unit:
	for u in get_parent().units.get_children():
		if u.pos == cell:
			return u
	return null

func _onMapPressed() -> void:
	var local_pos = get_local_mouse_position()
	var cell = terrain.local_to_map(local_pos)
	cell_clicked.emit(cell)
