extends Node2D

# Variables
var player_in_change_scene_area = false
var current_area : Area2D = null

# Variables - Data passed from scene before
var init_transition_data = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup player
	setup_player()
	
	# Setup scene with properties
	setup_scene()
	
	# Setup areas to change areaScenes
	setup_change_scene_areas()
	
	# Setup stair areas
	setup_stair_areas()
	
	# Say SceneManager that new_scene is ready
	Utils.get_scene_manager().finish_transition()

# Method to setup the player with all informations
func setup_player():
	# Setup player node with all settings like camera, ...
	Utils.get_current_player().setup_player_in_new_scene(find_node("Player"))
	
	# Set position
	Utils.calculate_and_set_player_spawn(self, init_transition_data)
		
	# Replace template player in scene with current_player
	find_node("Player").get_parent().remove_child(find_node("Player"))
	Utils.get_current_player().get_parent().remove_child(Utils.get_current_player())
	find_node("playerlayer").add_child(Utils.get_current_player())
	
	# Connect signals
	Utils.get_current_player().connect("player_collided", self, "collision_detected")
	Utils.get_current_player().connect("player_interact", self, "interaction_detected")

# Method to set transition_data which contains stuff about the player and the transition
func set_transition_data(transition_data):
	init_transition_data = transition_data

# Method to handle collision detetcion dependent of the collision object type
func interaction_detected():
	if player_in_change_scene_area:
		var next_scene_path = current_area.get_meta("next_scene_path")
		print("-> Change scene \"DUNGEON\" to \""  + str(next_scene_path) + "\"")
		var transition_data = TransitionData.GameArea.new(next_scene_path, current_area.get_meta("to_spawn_area_id"), Vector2(0, 1))
		Utils.get_scene_manager().transition_to_scene(transition_data)

# Method which is called when a body has entered a changeSceneArea
func body_entered_change_scene_area(body, changeSceneArea):
	if body.name == "Player":
		if changeSceneArea.get_meta("need_to_press_button_for_change") == false:
			var next_scene_path = changeSceneArea.get_meta("next_scene_path")
			print("-> Change scene \"GRASSLAND\" to \""  + str(next_scene_path) + "\"")
			var transition_data = TransitionData.GameArea.new(next_scene_path, changeSceneArea.get_meta("to_spawn_area_id"), Vector2(0, 1))
			Utils.get_scene_manager().transition_to_scene(transition_data)
		else:
			player_in_change_scene_area = true
			current_area = changeSceneArea

# Method which is called when a body has exited a changeSceneArea
func body_exited_change_scene_area(body, changeSceneArea):
	if body.name == "Player":
		print("-> Body \""  + str(body.name) + "\" EXITED changeSceneArea \"" + changeSceneArea.name + "\"")
		current_area = null
		player_in_change_scene_area = false
		
# Method which is called when a body has entered a stairArea
func body_entered_stair_area(body, stairArea):
	if body.name == "Player":
		# reduce player speed
		Utils.get_current_player().set_speed(0.6)

# Method which is called when a body has exited a stairArea
func body_exited_stair_area(body, stairArea):
	if body.name == "Player":
		# reset player speed
		Utils.get_current_player().reset_speed()

# Setup the scene with all importent properties on start
func setup_scene():
	find_node("dirt lvl0").cell_quadrant_size = 1
	find_node("dirt lvl0").cell_y_sort = false
	find_node("ground lvl0").cell_quadrant_size = 1
	find_node("ground lvl0").cell_y_sort = false
	find_node("decoration lvl0").cell_quadrant_size = 1
	find_node("decoration lvl0").cell_y_sort = false
	
	find_node("dirt lvl1").cell_quadrant_size = 1
	find_node("dirt lvl1").cell_y_sort = false
	find_node("ground lvl1").cell_quadrant_size = 1
	find_node("ground lvl1").cell_y_sort = false
	
	find_node("dirt lvl2").cell_quadrant_size = 1
	find_node("dirt lvl2").cell_y_sort = false
	find_node("ground lvl2").cell_quadrant_size = 1
	find_node("ground lvl2").cell_y_sort = false
	
	find_node("dirt lvl3").cell_quadrant_size = 1
	find_node("dirt lvl3").cell_y_sort = false
	find_node("ground lvl3").cell_quadrant_size = 1
	find_node("ground lvl3").cell_y_sort = false
	find_node("bridge lvl3").cell_quadrant_size = 1
	find_node("bridge lvl3").cell_y_sort = false
	
	find_node("dirt lvl4").cell_quadrant_size = 1
	find_node("dirt lvl4").cell_y_sort = false
	find_node("ground lvl4").cell_quadrant_size = 1
	find_node("ground lvl4").cell_y_sort = false


# Setup all change_scene objectes/Area2D's on start
func setup_change_scene_areas():
	var changeScenesObject = get_node("map_grassland/changeScenes")
	for child in changeScenesObject.get_children():
		if "changeScene" in child.name:
			# connect Area2D with functions to handle body action
			child.connect("body_entered", self, "body_entered_change_scene_area", [child])
			child.connect("body_exited", self, "body_exited_change_scene_area", [child])

# Setup all stair objectes/Area2D's on start
func setup_stair_areas():
	var stairsObject = get_node("map_grassland/ground/stairs")
	for stair in stairsObject.get_children():
		if "stairs" in stair.name:
			# connect Area2D with functions to handle body action
			stair.connect("body_entered", self, "body_entered_stair_area", [stair])
			stair.connect("body_exited", self, "body_exited_stair_area", [stair])
