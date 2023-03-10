# Credits goes to https://gist.github.com/fcingolani/035e43f57abf72801ec2e774fb89ad06


extends Node2D
class_name AStar2DVisualizer


export(float) var point_radius = 2.0
export(float) var scale_multiplier = 16.0 / 2.0
export(Color) var enabled_point_color = Color('00ff00')
export(Color) var disabled_point_color = Color('ff0000')
export(Color) var line_color = Color('0000ff')
export(float) var line_width = 1.1

var astar : AStar
var offset = Vector2(0,0)


func visualize(new_astar : AStar):
	print("ASTAR_VISUALIZER: Visualize")
	astar = new_astar
	update()


func update_disabled_points():
	update()


func _point_pos(id):
	var point = Vector2(astar.get_point_position(id).x, astar.get_point_position(id).y)
	return offset + point * scale_multiplier


func _draw():
	if not astar:
		return
	
	for point in astar.get_points():
		# Draw lines
#		for other in astar.get_point_connections(point):
#			draw_line(_point_pos(point), _point_pos(other), line_color, line_width)
		
		# Draw points
		# Enabled points
		if not astar.is_point_disabled(point):
			pass #draw_circle(_point_pos(point), point_radius, enabled_point_color)
		# Disabled points
		else:
			draw_circle(_point_pos(point), point_radius, disabled_point_color)
