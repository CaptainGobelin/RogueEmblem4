extends Node
class_name MapGenerator

func initTestMap(map: BattleMap) -> void:
	map.player_deploy_cells = [
		Vector2i(1, 2),
		Vector2i(1, 3),
		Vector2i(1, 4)
	]
	map.enemy_deploy_cells = [
		Vector2i(6, 2),
		Vector2i(6, 3),
		Vector2i(6, 4)
	]
