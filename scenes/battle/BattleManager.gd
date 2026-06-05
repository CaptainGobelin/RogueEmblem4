extends Node
class_name BattleManager

enum Turn { PLAYER, ENEMY }
signal turnStarted(turn: Turn)
signal turnEnded(turn: Turn)

var currentTurn: Turn = Turn.PLAYER

func registerUnit(unit : UnitPawn) -> void:
	turnStarted.connect(unit._onNewTurn)

func startBattle() -> void:
	currentTurn = Turn.PLAYER
	turnStarted.emit(currentTurn)

func endTurn() -> void:
	turnEnded.emit(currentTurn)
	match currentTurn:
		Turn.PLAYER:
			currentTurn = Turn.ENEMY
		Turn.ENEMY:
			currentTurn = Turn.PLAYER
	turnStarted.emit(currentTurn)

func isBattleOver() -> void:
	var playerAlive := false
	var enemyAlive := false
	for unit in Ref.units.get_children():
		if unit.team == UnitPawn.Team.PLAYER:
			if not unit.isDead:
				playerAlive = true 
		if unit.team == UnitPawn.Team.ENEMY:
			if not unit.isDead:
				enemyAlive = true
	if not enemyAlive:
		print("VICTORY")
	elif not playerAlive:
		print("DEFEAT")
