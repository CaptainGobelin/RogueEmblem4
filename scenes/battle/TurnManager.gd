extends Node
class_name TurnManager

enum Turn { PLAYER, ENEMY }
signal turnStarted(turn: Turn)
signal turnEnded(turn: Turn)

var currentTurn: Turn = Turn.PLAYER

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

func registerUnit(unit : Unit) -> void:
	turnStarted.connect(unit._onNewTurn)
