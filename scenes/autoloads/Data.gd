extends Node

enum actions {
	ATTACK,
	WAIT
}

const baseUISize: Vector2i = Vector2i(768, 432)

const CELL_SIZE: int = 16
const neighbors: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1) 
]
const cellRings = {
	1: [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)],
	2: [
		Vector2i(-2, 0), Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)
	],
	3: [
		Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, 0), Vector2i(0, 3),
		Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(2, -1),
		Vector2i(2, 1), Vector2i(1, 2), Vector2i(-1, 2), Vector2i(-2, 1)
	]
}
