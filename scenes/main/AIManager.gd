extends Node
class_name AIManager

@onready var tilemap: TileMapLayer = $TileMapLayer

var debugCells: Dictionary[Vector2i, Vector2] = {}

func aiTurn(units: Node, map: BattleMap) -> void:
	await performEnemyTurn()
	#for e:Unit in units.get_children():
		#if e.team == Unit.Team.ENEMY and not e.isDead:
			#map.getUnitReach(e)
			#for u:Unit in units.get_children():
				#if u.team == Unit.Team.PLAYER:
					#if map.attackMap.has(u.pos):
						#e.moveTo(map.attackMap[u.pos])
						#e.attack(u)
						#break

func performEnemyTurn() -> void:
	var waitingEnemies: Array[Unit] = []
	for u in Ref.units.get_children():
		if not u.has_acted and u.team == Unit.Team.ENEMY:
			waitingEnemies.append(u)
	if waitingEnemies.is_empty():
		return
	var acted: bool = await executeEnemyRound(waitingEnemies)
	if not acted:
		return
	await performEnemyTurn()

func executeEnemyRound(enemyUnits: Array[Unit]) -> bool:
	var best_enemy: Unit = null
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	var selectedTarget: Unit = null
	for enemy in enemyUnits:
		var reachable_cells = Ref.map.getUnitReach(enemy)
		debugCells.clear()
		for cell in reachable_cells:
			var pressure := 0.0
			var danger := 0.0
			var attack_bonus := 0.0
			var localSelectedTarget: Unit = null
			var supportScore: float = 1.0
			
			for unit in getAllSurroundingUnits(enemy, cell):
				if unit.team == Unit.Team.ENEMY:
					supportScore += 1.0
				else:
					pressure += getUnitPressureScore(unit, enemy)
					danger += getUnitDangerScore(unit, enemy)
			for target in getAllAttackableUnits(enemy, cell):
				var bonus = getAttackBonus(enemy, target)
				if bonus > attack_bonus:
					localSelectedTarget = target
					attack_bonus = bonus
			var score = pressure - (danger / supportScore) + attack_bonus
			debugCells[cell] = Vector2(pressure + attack_bonus, (danger / supportScore))
			if score > best_score:
				best_score = score
				best_enemy = enemy
				best_cell = cell
				selectedTarget = localSelectedTarget
		await drawDebug()
		pass
	if best_enemy == null:
		return false
	Ref.map.moveUnit(best_enemy, best_cell)
	if not selectedTarget == null:
		best_enemy.attack(selectedTarget)
	else:
		best_enemy.wait()
	return true
	
func getUnitDangerScore(attacker: Unit, defender: Unit) -> float:
	var hitChance: float = float(attacker.aim - defender.def) / 100.0
	hitChance = clamp(hitChance, 0.10, 0.95)
	var dmgProportion: float = float(attacker.strength) / float(defender.maxHp)
	if attacker.speed >= 2 * defender.speed:
		dmgProportion *= 2
	var expectedDamage: float = hitChance * dmgProportion
	return clamp(expectedDamage, 0.4, 1.0)

func getUnitPressureScore(target: Unit, attacker: Unit) -> float:
	return getUnitDangerScore(attacker, target)

func getAttackBonus(attacker: Unit, defender: Unit) -> float:
	return 2.0 * (getUnitPressureScore(defender, attacker) / getUnitDangerScore(attacker, defender))

func getAllSurroundingUnits(unit: Unit, cell: Vector2i) -> Array[Unit]:
	var result: Array[Unit] = []
	var visited: Array[Vector2i] = []
	var queue = [{"cell": cell, "dist": 0}]
	while not queue.is_empty():
		var entry = queue.pop_front()
		var current = entry.cell
		var dist = entry.dist
		if dist > 4:
			continue
		if visited.has(current):
			continue
		visited.append(current)
		var u = Ref.map.getCellUnit(current)
		if u != null and u != unit:
			result.append(u)
		for n in Data.neighbors:
			queue.append({"cell": current + n, "dist": dist + 1})
	return result

func getAllAttackableUnits(unit: Unit, cell: Vector2i) -> Array[Unit]:
	return Ref.map.getAttackableUnits(unit, cell)

func drawDebug():
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	tilemap.clear()
	for c in debugCells.keys():
		#tilemap.set_cell(c, 0, Vector2(5, 1))
		#var tiledata = tilemap.get_cell_tile_data(c)
		img.set_pixelv(c, Color(
			clamp(debugCells[c].y, 0.0, 1.0),
			clamp(debugCells[c].x, 0.0, 1.0),
			0.0,
			0.55
		))
	$Sprite2D.texture.set_image(img)
	await get_tree().process_frame
