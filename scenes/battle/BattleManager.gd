extends Node
class_name BattleManager

@export var units : Node

func isBattleOver() -> void:
	var playerAlive := false
	var enemyAlive := false
	for unit in units.get_children():
		if unit.team == Unit.Team.PLAYER:
			if not unit.isDead:
				playerAlive = true 
		if unit.team == Unit.Team.ENEMY:
			if not unit.isDead:
				enemyAlive = true
	if not enemyAlive:
		print("VICTORY")
	elif not playerAlive:
		print("DEFEAT")
