# UnitManager.gd
class_name UnitManager
extends RefCounted

signal xpGain
signal levelUp(newLevel)
signal statGain(stat, newValue)
signal performAttack(isSuccess, defenderDead)

enum Team { PLAYER, ENEMY }

var id: int = -1
var baseStats: Array = [0, 0, 0, 0, 0, 0]
var currentHp: int = 1
var currentXp: int = 0
var currentLevel: int = 0
var baseMove: int = 0
var baseRange: Vector2i = Vector2i(1, 1)
var hiddenTrait: int = Data.Stats.STR
var isAlive: bool = true
var hasActed: bool = false
var team: Team = Team.PLAYER
var unitType: int = Data.Classes.FIGHTER
var unitName: String = "Rodriguo"

func _init(unitTeam: Team, classID: int, level: int):
	id = Global.getUnitID()
	unitType = classID
	team = unitTeam
	match team:
		Team.PLAYER:
			baseStats = Data.BASE_STATS.duplicate()
			var favStat = Data.CLASS_DATA[unitType][Data.CL_FAV_STAT]
			baseStats[favStat] += Data.GROWTH_AMOUNTS[favStat]
		Team.ENEMY:
			baseStats = Data.PROFILE_DATA[Data.MONSTER_DATA[unitType][Data.MO_PROFILE]][Data.PR_STATS].duplicate()
	currentHp = baseStats[Data.Stats.HP]
	if level > 0:
		for l in range(level):
			_levelUp()

func gainXp() -> void:
	if team != Team.PLAYER:
		return
	if currentLevel >= Data.XP_PER_BASE_LEVEL:
		_levelUp()
	else:
		currentXp += 1
		xpGain.emit()

func performCombat(defender: UnitManager, defenderCanReach: bool) -> void:
	_attack(defender)
	if defenderCanReach:
		defender._attack(self)
	if getSpd() >= 2 * defender.getSpd():
		_attack(defender)
	elif 2 * getSpd() <= defender.getSpd():
		if defenderCanReach:
			defender._attack(self)

func _attack(defender: UnitManager) -> void:
	if randf() < 0.01 * (getAim() - defender.getDef()):
		defender.sufferDamages(getDamages())
		performAttack.emit(true, not defender.isAlive)
	else:
		performAttack.emit(false, not defender.isAlive)

func sufferDamages(amount: int):
	currentHp = max(0, currentHp - amount)
	if currentHp == 0:
		die()

func die() -> void:
	isAlive = false

func _levelUp() -> void:
	currentXp = 0
	currentLevel += 1
	match team:
		Team.PLAYER:
			for s in Data.Stats:
				if _playerStatIncrease(s):
					statGain.emit(s, baseStats[s])
		Team.ENEMY:
			for s in Data.Stats:
				_aiStatsIncrease(s)
	levelUp.emit(currentLevel)

func _playerStatIncrease(statID: int) -> bool:
	var increaseChance: float = Data.CLASS_DATA[unitType][Data.CL_GROWTH][statID]
	if statID == hiddenTrait:
		increaseChance += Data.HIDDEN_TRAIT_GROWTH
	if randf() <= increaseChance:
		baseStats += Data.GROWTH_AMOUNTS[statID]
		if statID == Data.Stats.HP:
			currentHp += Data.GROWTH_AMOUNTS[statID]
		return true
	return false

func _aiStatsIncrease(statID: int) -> void:
	var growthValue: float = 1.0 * currentLevel
	var profile = Data.PROFILE_DATA[Data.MONSTER_DATA[unitType][Data.MO_PROFILE]] 
	growthValue =  Data.GROWTH_RATES[Data.PROFILE_DATA[Data.MONSTER_DATA[unitType][Data.MO_PROFILE]][Data.PR_GROWTH][statID]]
	baseStats[statID] = int(round(growthValue)) * Data.GROWTH_AMOUNTS[statID] + profile[Data.PR_STATS][statID]
	if statID == Data.Stats.HP:
		currentHp = baseStats[statID]

# When statuses get implemented add parameters: trigger: int = -1, context: Variant = null
# context is meant to contains any object useful like defender in the fight context
func getMaxHP(trigger: int = -1, context: Variant = null) -> int:
	if trigger == -1:
		return baseStats[Data.Stats.HP]
	return baseStats[Data.Stats.HP]

func getStr() -> int:
	return baseStats[Data.Stats.STR]

func getSpd() -> int:
	return baseStats[Data.Stats.SPD]

func getMag() -> int:
	return baseStats[Data.Stats.MAG]

func getDef() -> int:
	return baseStats[Data.Stats.DEF]

func getAim() -> int:
	return baseStats[Data.Stats.AIM]

func getMove() -> int:
	return baseMove

func getRange() -> Vector2i:
	return baseRange

func getDamages() -> int:
	return getStr()
