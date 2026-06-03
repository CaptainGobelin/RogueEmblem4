# Campaign.gd
class_name Campaign
extends Node

static var battleScene = preload("res://scenes/main/BattleScene.tscn")

enum GameMode { BATTLE_DEMO }
@export var mode: GameMode = GameMode.BATTLE_DEMO

@onready var currentScene: Node = $CurrentScene
var playerTeam: Dictionary = {}
var inventory: Dictionary = {}

func _ready():
	match mode:
		GameMode.BATTLE_DEMO:
			startDemoBattle()

func startDemoBattle() -> void:
	for i in range(3):
		var unit = UnitManager.new(UnitManager.Team.PLAYER, randi() % 5 + Data.Classes.FIGHTER, 0)
		playerTeam[unit.id] = unit

func loadBattleScene() -> void:
	_clearScene()
	var scene := battleScene.instantiate()
	currentScene.add_child(scene)
	scene.createDemoMap()
	scene.deployPlayerTeam(playerTeam.values())

func _clearScene() -> void:
	for c in currentScene.get_children():
		c.queue_free()
