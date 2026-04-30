class_name TooltipMenu
extends Control

@export var margin := 4

var uiRoot: CanvasLayer
var camera: Camera2D
var target: Node2D

var _debugAnchor := Vector2.ZERO
var _debugCandidates: Array[Rect2] = []

func _ready():
	visible = false
	call_deferred("_resolveRefs")

func _resolveRefs():
	assert(Ref.ui != null)
	uiRoot = Ref.ui
	assert(Ref.camera != null)
	camera = Ref.camera

# --------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------

func open(onTarget: Node2D):
	target = onTarget
	visible = true
	_updatePosition()
	# Reposition when window size changes
	#TODO camera move/zoom
	get_tree().root.size_changed.connect(_updatePosition)
	target.item_rect_changed.connect(_updatePosition)

func close():
	if not visible:
		return
	#TODO check connection before disconnect
	get_tree().root.size_changed.disconnect(_updatePosition)
	target.item_rect_changed.disconnect(_updatePosition)
	visible = false
	target = null

# --------------------------------------------------------------------
# Positioning
# --------------------------------------------------------------------

func _updatePosition():
	if not visible or not target:
		return
	if camera == null:
		return
	#var worldPos = target.global_position# + Data.worldOffset
	#var screenPos = camera.world_to_screen(worldPos)
	#var uiAnchor = uiRoot.to_local(screenPos)
	#_placeTooltip(uiAnchor)
	_placeTooltip(target.global_position + Vector2(margin, 0))
	#if Debug.debugTooltips:
		#queue_redraw()


func _placeTooltip(uiAnchor: Vector2):
	var s := size
	_debugAnchor = uiAnchor
	_debugCandidates.clear()
	var candidates := [
		uiAnchor + Vector2( margin, -s.y / 2),        # right
		uiAnchor + Vector2(-s.x - margin, -s.y / 2),  # left
	]
	for pos in candidates:
		var rect := Rect2(pos, s)
		_debugCandidates.append(rect)
		if _fitsOnScreen(rect):
			position = pos
			return
	position = candidates[0]


func _fitsOnScreen(rect: Rect2) -> bool:
	return (
		rect.position.x >= 0 and
		rect.position.y >= 0 and
		rect.position.x + rect.size.x <= Data.baseUISize.x and
		rect.position.y + rect.size.y <= Data.baseUISize.y
	)

# --------------------------------------------------------------------
# Debug Visualization
# --------------------------------------------------------------------

#func _draw():
	#if not Debug.debugTooltips:
		#return
	## Anchor point (world → UI)
	#draw_circle(_debugAnchor, 2, Debug.FadeColor.CYAN)
	## Candidate rectangles
	#for rect in _debugCandidates:
		#if _fitsOnScreen(rect):
			#draw_rect(rect, Debug.FadeColor.GREEN, false, 1)
		#else:
			#draw_rect(rect, Debug.FadeColor.RED, false, 1)
