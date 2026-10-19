@tool
@icon("res://addons/regatta_editor/icons/rose.svg")
class_name ChartRose
extends Node3D
## Kompassrose als Kartendekoration.

@export_range(10.0, 120.0, 1.0, "suffix:m") var radius := 32.0:
	set(v):
		radius = v
		_rebuild()

var _vis: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	SeaChart.build_compass_rose(_vis, radius)
