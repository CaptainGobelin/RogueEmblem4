extends Node
class_name BattleManager

@export var units : Node

func isBattleOver() -> void:
	var playerAlive := false
	var enemyAlive := false
	for unit in units.get_children():
		if unit is Unit:
			if unit.team == Unit.Team.PLAYER:
				playerAlive = true
			if unit.team == Unit.Team.ENEMY:
				enemyAlive = true
	if not enemyAlive:
		print("VICTORY")
	elif not playerAlive:
		print("DEFEAT")
