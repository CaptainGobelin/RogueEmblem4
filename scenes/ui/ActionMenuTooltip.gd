extends TooltipMenu
class_name  ActionMenuTooltip

signal attackClicked
signal waitClicked

func _onAttackButtonPressed() -> void:
	emit_signal("attackClicked")

func _onWaitButtonPressed() -> void:
	emit_signal("waitClicked")
