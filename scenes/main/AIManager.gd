extends Node
class_name AIManager

const HEATMAP_ALPHA = 0.55
const ENEMY_POWER_RATIO = 3.0
const ATK_FACTOR = 2.0
const THREAT_RANGE = 5
const SUPPORT_RANGE = 3

@onready var heatmap: Sprite2D = $Heatmap

var debugCells: Dictionary[Vector2i, Vector2] = {}

func performEnemyTurn() -> void:
	var activated: Array[Unit] = []
	var threatCells: Dictionary = _computeThreatCells() # Vector2i -> [[Enemies], [Allies]]
	for e in Ref.units.get_children():
		if e.hasActed or e.team != Unit.Team.ENEMY:
			continue
		if _isThreatened(e, threatCells):
			activated.append(e)
	while true:
		if activated.is_empty():
			return
		var bestScore: float = 0.0
		var bestUnit: Unit = null
		var bestCell: Vector2i = Vector2i(-1, -1)
		for e in activated:
			var reach = Ref.map.getUnitReach(e)
			for c in reach:
				var score = _getCellScore(e, c, threatCells)
				if score > bestScore:
					bestScore = score
					bestUnit = e
					bestCell = c
			if Debug.debugAi:
				await _drawDebug()
		if bestScore <= 0:
			return
		_activateNearbyAllies(bestUnit, activated)
		await Ref.map.moveUnit(bestUnit, bestCell)
		var target: Unit = _getBestTarget(bestUnit, bestUnit.pos)
		if target != null:
			await bestUnit.attack(target)
		else:
			await bestUnit.wait()
		_propagateSupport(bestUnit, threatCells)
		activated.erase(bestUnit)

func _computeThreatCells() -> Dictionary:
	var result: Dictionary = {}
	for u in Ref.units.get_children():
		if u.team == Unit.Team.ENEMY:
			continue
		var threatCell = _getUnitThreat(u)
		for c in threatCell:
			if result.has(c):
				result[c][0].append(u)
			else:
				result[c] = [[u], []]
	return result

func _isThreatened(unit: Unit, threatCells: Dictionary) -> bool:
	return threatCells.has(unit.pos)

func _getBestTarget(unit: Unit, cell: Vector2i) -> Unit:
	var result: Unit = Unit.INVALID
	var bestScore := 0.0
	for t in Ref.map.getAttackableUnits(unit, cell):
		var score := _getUnitPressureScore(t, unit)
		if score > bestScore:
			result = t
	return result

func _activateNearbyAllies(unit: Unit, activated: Array[Unit]) -> void:
	for a in Ref.map.getNearbyUnits(unit.pos, unit.team, SUPPORT_RANGE):
		if a.hasActed or activated.has(a):
			continue
		activated.append(a)

func _propagateSupport(unit: Unit, threatCells: Dictionary):
	for c in _getUnitThreat(unit):
		if threatCells.has(c):
			threatCells[c][1].append(unit)
	
func _getUnitThreat(unit: Unit) -> Array[Vector2i]:
	var visited: Array[Vector2i] = []
	var queue = [{"cell": unit.pos, "dist": 0}]
	while not queue.is_empty():
		var entry = queue.pop_front()
		var current = entry.cell
		var dist = entry.dist
		if dist > THREAT_RANGE:
			continue
		if visited.has(current):
			continue
		visited.append(current)
		for n in Data.neighbors:
			queue.append({"cell": current + n, "dist": dist + 1})
	return visited

func _getCellScore(unit: Unit, cell: Vector2i, threatCells: Dictionary) -> float:
	if not threatCells.has(cell):
		return 0.0
	var pressure := 0.0
	var danger := 0.0
	var atkBonus := 0.0
	var support := 1.0 + float(threatCells[cell][1].size())
	var targets := Ref.map.getAttackableUnits(unit, cell)
	for t in threatCells[cell][0]:
		pressure = max(pressure, _getUnitPressureScore(t, unit))
		danger += _getUnitDangerScore(t, unit)
		if targets.has(t):
			atkBonus = max(atkBonus, ATK_FACTOR * _getUnitPressureScore(t, unit))
	if Debug.debugAi:
		debugCells[cell] = Vector2(pressure + atkBonus, danger / support)
	return pressure + atkBonus - (danger / support)
	
func _getUnitDangerScore(attacker: Unit, defender: Unit) -> float:
	var damages := _getExpectedDamage(attacker, defender)
	return clamp(damages / ENEMY_POWER_RATIO, 0.4, 1.0)

func _getUnitPressureScore(target: Unit, attacker: Unit) -> float:
	var damages := _getExpectedDamage(attacker, target)
	return clamp(damages * ENEMY_POWER_RATIO, 0.4, 1.0)

func _getExpectedDamage(attacker: Unit, defender: Unit) -> float:
	var hitChance: float = float(attacker.aim - defender.def) / 100.0
	hitChance = clamp(hitChance, 0.10, 0.95)
	var dmgProportion: float = float(attacker.strength) / float(defender.maxHp)
	if attacker.speed >= 2 * defender.speed:
		dmgProportion *= 2
	return hitChance * dmgProportion
	
func _drawDebug():
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for c in debugCells.keys():
		img.set_pixelv(c, Color(
			clamp(debugCells[c].y, 0.0, 1.0),
			clamp(debugCells[c].x, 0.0, 1.0),
			0.0,
			HEATMAP_ALPHA
		))
	heatmap.texture.set_image(img)
	heatmap.visible = true
	await get_tree().process_frame
	heatmap.visible = false
