# GLOBAL.gd
extends Node

var unitID: int = -1
func getUnitID() -> int:
	unitID += 1
	return unitID
	
var statusID: int = -1
func getStatusID() -> int:
	statusID += 1
	return statusID

var itemID: int = -1
func getItemID() -> int:
	itemID += 1
	return itemID

var statuses: Dictionary = {}
var items: Dictionary = {}
