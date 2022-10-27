extends Node2D


# Map specific
var scene_type = Constants.SceneType.CAMP

# Variables
var thread
var player_in_change_scene_area = false
var current_area : Area2D = null

# Variables - Data passed from scene before
var init_transition_data = null

# Nodes
onready var changeScenesObject = $map_camp/changeScenes
onready var groundChunks = $map_camp/ground/Chunks
onready var higherChunks = $map_camp/higher/Chunks

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup player
	setup_player()
	
	
	# Setup chunks and chunkloader
	# Get map position
	var vertical_chunks_count = groundChunks.get_meta("vertical_chunks_count") - 1
	var horizontal_chunks_count = groundChunks.get_meta("horizontal_chunks_count") - 1
	var map_min_global_pos = groundChunks.get_meta("map_min_global_pos")
	ChunkLoaderService.init(self, vertical_chunks_count, horizontal_chunks_count, map_min_global_pos)
	
	# setup areas to change areaScenes
	setup_change_scene_areas()
	# setup all door areas to handle action
	setup_door_areas()
	
	# Say SceneManager that new_scene is ready
	Utils.get_scene_manager().finish_transition()


# Method to destroy the scene
# Is called when SceneManager changes scene after loading new scene
func destroy_scene():
	# Stop chunkloader
	ChunkLoaderService.cleanup()
	
	# Disconnect signals
	clear_signals()


# Method to setup the player with all informations
func setup_player():
	var scene_player = find_node("Player")
	
	# Setup player node with all settings like camera, ...
	Utils.get_current_player().setup_player_in_new_scene(scene_player)
	
	# Set position
	Utils.calculate_and_set_player_spawn(self, init_transition_data)
	
	# Replace template player in scene with current_player
	scene_player.get_parent().remove_child(scene_player)
	Utils.get_current_player().get_parent().remove_child(Utils.get_current_player())
	find_node("playerlayer").add_child(Utils.get_current_player())
	
	# Connect signals
	Utils.get_current_player().connect("player_collided", self, "collision_detected")
	Utils.get_current_player().connect("player_interact", self, "interaction_detected")

# Method to set transition_data which contains stuff about the player and the transition
func set_transition_data(transition_data):
	init_transition_data = transition_data

# Method to handle collision detetcion dependent of the collision object type
func collision_detected(collision):
	var _type = collision.get_parent().get_meta("type") # type is string
	print("collision_detected")
	
# Method to handle collision detetcion dependent of the collision object type
func interaction_detected():
	if player_in_change_scene_area:
		Utils.get_current_player().set_change_scene(true)
		var next_scene_path = current_area.get_meta("next_scene_path")
		print("-> Change scene \"DUNGEON\" to \""  + str(next_scene_path) + "\"")
		var transition_data = TransitionData.GameArea.new(next_scene_path, current_area.get_meta("to_spawn_area_id"), Vector2(0, 1))
		Utils.get_scene_manager().transition_to_scene(transition_data)
		
		
# Method which is called when a body has entered a doorArea
func body_entered_door(body, doorArea):
	if body.name == "Player":
		for child in doorArea.get_children():
			if "animationPlayer" in child.name:
				# Start door animation
				child.play("openDoor")

# Method which is called when a body has exited a doorArea
func body_exited_door(body, doorArea):
	if body.name == "Player":
		for child in doorArea.get_children():
			if "animationPlayer" in child.name:
				# Start door animation
				child.play("closeDoor")

# Method which is called when a body has entered a changeSceneArea
func body_entered_change_scene_area(body, changeSceneArea):
	if body.name == "Player":
		if changeSceneArea.get_meta("need_to_press_button_for_change") == false:
			var next_scene_path = changeSceneArea.get_meta("next_scene_path")
			print("-> Change scene \"CAMP\" to \""  + str(next_scene_path) + "\"")
			var transition_data = TransitionData.GameArea.new(next_scene_path, changeSceneArea.get_meta("to_spawn_area_id"), Vector2(0, -1))
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

# Setup all change_scene objectes/Area2D's on start
func setup_change_scene_areas():
	for child in changeScenesObject.get_children():
		if "changeScene" in child.name:
			# connect Area2D with functions to handle body action
			child.connect("body_entered", self, "body_entered_change_scene_area", [child])
			child.connect("body_exited", self, "body_exited_change_scene_area", [child])

# Setup all door objectes/Area2D's on start
func setup_door_areas():
	for chunk in groundChunks.get_children():
		var doors_object = chunk.find_node("doors")
		if doors_object != null:
			for door in doors_object.get_children():
				if door is Area2D:
					# connect Area2D with functions to handle body action
					door.connect("body_entered", self, "body_entered_door", [door])
					door.connect("body_exited", self, "body_exited_door", [door])


# Method to update the chunks with active and deleted chunks to make them visible or not
func update_chunks(new_chunks : Array, deleting_chunks : Array):
	# Activate chunks
	for chunk in new_chunks:
		var ground_chunk = groundChunks.get_node("Chunk (" + str(chunk.x) + "," + str(chunk.y) + ")")
		if ground_chunk != null:
			ground_chunk.visible = true
		var higher_chunk = higherChunks.get_node("Chunk (" + str(chunk.x) + "," + str(chunk.y) + ")")
		if higher_chunk != null:
			higher_chunk.visible = true

	# Disable chunks
	for chunk in deleting_chunks:
		var ground_chunk = groundChunks.get_node("Chunk (" + str(chunk.x) + "," + str(chunk.y) + ")")
		if ground_chunk != null:
			ground_chunk.visible = false
		var higher_chunk = higherChunks.get_node("Chunk (" + str(chunk.x) + "," + str(chunk.y) + ")")
		if higher_chunk != null:
			higher_chunk.visible = false


# Method to disconnect all signals
func clear_signals():
	# Player
	Utils.get_current_player().disconnect("player_collided", self, "collision_detected")
	Utils.get_current_player().disconnect("player_interact", self, "interaction_detected")
	
	# Change scenes
	for child in changeScenesObject.get_children():
		if "changeScene" in child.name:
			# connect Area2D with functions to handle body action
			child.disconnect("body_entered", self, "body_entered_change_scene_area")
			child.disconnect("body_exited", self, "body_exited_change_scene_area")
	
	# Doors
	for chunk in groundChunks.get_children():
		var doors_object = chunk.find_node("doors")
		if doors_object != null:
			for door in doors_object.get_children():
				if door is Area2D:
					# connect Area2D with functions to handle body action
					door.disconnect("body_entered", self, "body_entered_door")
					door.disconnect("body_exited", self, "body_exited_door")
