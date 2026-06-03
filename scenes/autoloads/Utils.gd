extends Node

func chooseRandom(array: Array):
	return array[randi() % array.size()]

func modulo(a: int, b: int):
	return (b + (a % b)) % b

func gaussRand() -> float:
	return (randf() + randf()) / 2 

func dist(a: Vector2, b: Vector2) -> int:
	return int(abs(a.x - b.x) + abs(a.y - b.y))

func squareDist(a: Vector2, b: Vector2) -> int:
	return int(sqrt(pow(b.x-a.x, 2) + pow(b.y-a.y, 2)))

func printDict(dict: Dictionary):
	if dict.is_empty():
		print("Empty dict")
	for k in dict.keys():
		prints(String(k), ":", dict[k])
