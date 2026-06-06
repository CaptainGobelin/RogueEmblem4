extends Node
class_name TacticalQuery

enum Quadrant {NE, SE, SW, NW}

class Path:
	var length: int = 0
	var cells: Array[Vector2i] = []
	
	func add(cell: Vector2i) -> Path:
		length += 1
		cells.push_front(cell)
		return self
	
	func isShorter(compared: Path) -> bool:
		if length >= compared.length:
			return false
		return true
	
	func copy() -> Path:
		var result: Path = Path.new()
		result.length = length
		result.cells = cells.duplicate(true)
		return result

var wallsPerQuadrant: Dictionary = {}

# ==============================================================================
# Public
# ==============================================================================

func computeMoveMap(unit: UnitPawn) -> Dictionary[Vector2i, TacticalQuery.Path]:
	var reach: Dictionary[Vector2i, Path] = {unit.pos: Path.new()}
	var visited: Dictionary[Vector2i, Path] = {unit.pos: Path.new()}
	var lastAdded: Array[Vector2i] = [unit.pos]
	for i in range(unit.entity.getMove()):
		var newAdded: Array[Vector2i] = []
		for c in lastAdded:
			for n in Data.neighbors:
				if not visited.has(c + n) and get_parent().isCellPassable(unit, c + n):
					if get_parent().isCellFree(unit, c + n):
						reach[c + n] = visited[c].copy().add(c)
					visited[c + n] = visited[c].copy().add(c)
					newAdded.append(c + n)
		lastAdded = newAdded
	return reach

func computeAttackMap(unit: UnitPawn, reach: Array[Vector2i]) -> Dictionary[Vector2i, Vector2i]:
	var origin = unit.position
	var allWalls: Array[Vector2i] = Ref.map.terrain.get_used_cells_by_id(0, Vector2i(1, 0))
	wallsPerQuadrant = _computeWallsPerQuadrant(origin, unit.entity.getRange()[1], allWalls)
	var attackMap: Dictionary[Vector2i, Vector2i] = {}
	for r in reach:
		for a in _getAtkRing(unit):
			var target = r + a
			if attackMap.has(target):
				continue
			if _isBlockedByWall(origin, target):
				continue
			attackMap[target] = r
	return attackMap

func getNearbyArea(cell: Vector2i, areaRange: int) -> Array[Vector2i]:
	var reach: Array[Vector2i] = [cell]
	var visited: Array[Vector2i] = [cell]
	var lastAdded: Array[Vector2i] = [cell]
	for i in range(areaRange):
		var newAdded: Array[Vector2i] = []
		for c in lastAdded:
			for n in Data.neighbors:
				if not visited.has(c + n) and get_parent().isCellPassable(UnitPawn.INVALID, c + n):
					if get_parent().isCellFree(UnitPawn.INVALID, c + n):
						reach.append(c + n)
					visited.append(c + n)
					newAdded.append(c + n)
		lastAdded = newAdded
	return reach

# ==============================================================================
# Private
# ==============================================================================

func _getQuadrantDirection(origin: Vector2i, target: Vector2i) -> Quadrant:
	if target.x >= origin.x:
		if target.y >= origin.y:
			return Quadrant.NE
		return Quadrant.SE
	if target.y <= origin.y:
		return Quadrant.SW
	return Quadrant.NW

func _isBlockedByWall(origin: Vector2i, target: Vector2i) -> bool:
	var quadrant = _getQuadrantDirection(origin, target)
	for w in wallsPerQuadrant[quadrant]:
		match quadrant:
			Quadrant.NE:
				if w.x <= target.x and w.y <= target.y:
					return true
			Quadrant.SE:
				if w.x <= target.x and w.y >= target.y:
					return true
			Quadrant.SW:
				if w.x >= target.x and w.y >= target.y:
					return true
			Quadrant.NW:
				if w.x >= target.x and w.y <= target.y:
					return true
	return false

func _computeWallsPerQuadrant(origin: Vector2i, r: int, walls: Array[Vector2i]) -> Dictionary:
	var result = {
		Quadrant.NE: [],
		Quadrant.SE: [],
		Quadrant.SW: [],
		Quadrant.NW: []
	}
	for w in walls:
		if abs(origin.x - w.x) > r or abs(origin.y - w.y) > r:
			continue
		var quadrant = _getQuadrantDirection(origin, w)
		result[quadrant].append(w)
	return result

func _getAtkRing(unit: UnitPawn) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r in range(unit.entity.getRange()[0], unit.entity.getRange()[1] + 1):
		result.append_array(Data.cellRings[r])
	return result
