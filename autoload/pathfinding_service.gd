extends Node


# Signals
signal map_loaded(map_name)

# Variables
var pathfinder_thread = Thread.new()
var mobs_to_update : Dictionary = {}
var enemies_to_update = []
var bosses_to_update = []
var ambient_mobs_to_update = []
var mobs_waiting = []
var bosses_waiting = []
var mobs_check_can_reach_player = []
var can_generate_pathes = false
var should_generate_pathes = false
var preload_stopped = false

var ambientMobsNavigationTileMap : TileMap = null
var ambientMobsNavigationTileMap_mutex = Mutex.new()
var map_size_in_tiles = null
var map_min_global_pos = null
var map_offset_in_tiles = null
var half_cell_size = null
var map_name
var astar_nodes_cache = {}
var astar_nodes_cache_mutex = Mutex.new()
var astar2DVisualizerNode = null
var mobs_with_new_position : Dictionary = {}
var mobs_with_new_position_mutex = Mutex.new()
var bosses_with_new_position : Dictionary = {}
var bosses_with_new_position_mutex = Mutex.new()

func _ready():
	print("PATHFINDING_SERVICE: Start")


# Method to preload the astar nodes
func preload_astars():
	# Load astar points and connections
	var astar_nodes_file_dics : Dictionary = FileManager.load_astar_files()
	
	for astar_dic_key in astar_nodes_file_dics.keys():
		var iterating_map_name = astar_dic_key
		
		# Check if preload is canceled
		if preload_stopped:
			return
		
		# For debugging
		if "grassland" in iterating_map_name and not Constants.LOAD_GRASSLAND_MAP:
			# Skip grassland
			printerr("PATHFINDING: NOT LOADED MAP \"" + str(iterating_map_name) + "\"")
			continue
		elif "dungeon" in iterating_map_name and not Constants.LOAD_DUNGEONS_MAPS:
			# Skip all dungeons
			printerr("PATHFINDING: NOT LOADED MAP \"" + str(iterating_map_name) + "\"")
			continue
		
		
		# Create new AStars and store them to use later again
		astar_nodes_cache_mutex.lock()
		if not astar_nodes_cache.has(iterating_map_name):
			astar_nodes_cache[iterating_map_name] = {
								"mobs" : null,
								"bosses" : null,
								"ambient_mobs" : null,
								"dynamic_obstacles_mobs" : {},
								"dynamic_obstacles_bosses" : {},
								"mobs_mutex" : Mutex.new(),
								"bosses_mutex" : Mutex.new(),
								"ambient_mobs_mutex" : Mutex.new(),
								"dynamic_obstacles_mobs_mutex" : Mutex.new(),
								"dynamic_obstacles_bosses_mutex" : Mutex.new()
								}
		astar_nodes_cache_mutex.unlock()
		
		# Mobs
		astar_nodes_cache[iterating_map_name]["mobs_mutex"].lock()
		astar_nodes_cache[iterating_map_name]["mobs"] = CustomAstar.new()
		astar_nodes_cache[iterating_map_name]["mobs_mutex"].unlock()
		astar_add_walkable_cells_for_mobs(astar_nodes_file_dics[iterating_map_name]["mobs"]["points"], iterating_map_name)
		astar_connect_walkable_cells_for_mobs(astar_nodes_file_dics[iterating_map_name]["mobs"]["points"], iterating_map_name)
		
		# Check if preload is canceled
		if preload_stopped:
			return
		
		# Bosses
		if astar_nodes_file_dics[iterating_map_name]["bosses"]["points"].size() > 0:
			astar_nodes_cache[iterating_map_name]["bosses_mutex"].lock()
			astar_nodes_cache[iterating_map_name]["bosses"] = CustomAstar.new()
			astar_nodes_cache[iterating_map_name]["bosses_mutex"].unlock()
			astar_add_walkable_cells_for_bosses(astar_nodes_file_dics[iterating_map_name]["bosses"]["points"], iterating_map_name)
			astar_connect_walkable_cells_for_bosses(astar_nodes_file_dics[iterating_map_name]["bosses"]["points"], iterating_map_name)
		
		# Check if preload is canceled
		if preload_stopped:
			return
		
		# Ambient mobs
		if astar_nodes_file_dics[iterating_map_name]["ambient_mobs"]["points"].size() > 0:
			astar_nodes_cache[iterating_map_name]["ambient_mobs_mutex"].lock()
			astar_nodes_cache[iterating_map_name]["ambient_mobs"] = CustomAstar.new()
			astar_nodes_cache[iterating_map_name]["ambient_mobs_mutex"].unlock()
			astar_add_walkable_cells_for_ambient_mobs(astar_nodes_file_dics[iterating_map_name]["ambient_mobs"]["points"], iterating_map_name)
			astar_connect_walkable_cells_for_ambient_mobs(astar_nodes_file_dics[iterating_map_name]["ambient_mobs"]["points"], iterating_map_name)
		
		# Emit signal that map is loaded
		emit_signal("map_loaded", iterating_map_name)
		
		print("PATHFINDING: LOADED MAP \"" + str(iterating_map_name) + "\"")
	
	astar_nodes_file_dics.clear()


# Method to stop preloading -> is called if game is closed while loading/StartScreen
func stop_preloading():
	preload_stopped = true


# Method is called when new scene is loaded with mobs with pathfinding
func init(new_map_name = "", new_astar2DVisualizerNode = null, new_ambientMobsNavigationTileMap : TileMap = null, new_map_size_in_tiles : Vector2 = Vector2.ZERO, new_map_min_global_pos = null):
	print("PATHFINDING_SERVICE: Init")
	# Check if thread is active wait to stop
	if pathfinder_thread.is_active():
		clean_thread()
	
	# Init variables
	map_name = new_map_name
	ambientMobsNavigationTileMap = new_ambientMobsNavigationTileMap
	
	map_size_in_tiles = new_map_size_in_tiles
	map_min_global_pos = new_map_min_global_pos
	map_offset_in_tiles = map_min_global_pos / Constants.TILE_SIZE
	half_cell_size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) / 2
	
	# Start pathfinder thread
	pathfinder_thread.start(self, "generate_pathes")
	can_generate_pathes = true
	
	# Init visualizer
	if Constants.CAN_DEBUG and Constants.SHOW_PATHFINDING_POINTS:
		astar2DVisualizerNode = new_astar2DVisualizerNode
		if astar2DVisualizerNode != null:
			astar2DVisualizerNode.call_deferred("visualize", astar_nodes_cache[map_name]["mobs"])


# Method to start pathfinding service (call after init)
func start():
	should_generate_pathes = true


# Method to stop the pathfinder to change map
func stop():
	# Delete variables
	enemies_to_update = null
	bosses_to_update = null
	ambient_mobs_to_update = null
	can_generate_pathes = null
	should_generate_pathes = null
	mobs_waiting = null
	bosses_waiting = null
	mobs_check_can_reach_player = null
	
	map_name = null
	if astar_nodes_cache != null:
		astar_nodes_cache.clear()
	astar_nodes_cache = null
	
	print("PATHFINDING_SERVICE: Stopped")


# Method to cleanup the pathfinder
func cleanup():
	# Check if thread is active wait to stop
	can_generate_pathes = false
	should_generate_pathes = false
	
	if pathfinder_thread.is_active():
		clean_thread()
	
	# Clean variables
	mobs_to_update.clear()
	enemies_to_update.clear()
	bosses_to_update.clear()
	ambient_mobs_to_update.clear()
	ambientMobsNavigationTileMap = null
	map_size_in_tiles = null
	map_min_global_pos = null
	map_offset_in_tiles = null
	half_cell_size = null
	astar2DVisualizerNode = null
	mobs_waiting.clear()
	bosses_waiting.clear()
	mobs_check_can_reach_player.clear()
	mobs_with_new_position.clear()
	bosses_with_new_position.clear()
	
	# Clean MOBS dynamic obstacles
	if not astar_nodes_cache[map_name]["dynamic_obstacles_mobs"].empty():
		for obstacle in astar_nodes_cache[map_name]["dynamic_obstacles_mobs"].keys():
			for point_index in astar_nodes_cache[map_name]["dynamic_obstacles_mobs"][obstacle]:
				astar_nodes_cache[map_name]["mobs"].set_point_disabled(point_index, false)
		astar_nodes_cache[map_name]["dynamic_obstacles_mobs"].clear()
	
	# Clean BOSSES dynamic obstacles
	if not astar_nodes_cache[map_name]["dynamic_obstacles_bosses"].empty():
		for obstacle in astar_nodes_cache[map_name]["dynamic_obstacles_bosses"].keys():
			for point_index in astar_nodes_cache[map_name]["dynamic_obstacles_bosses"][obstacle]:
				astar_nodes_cache[map_name]["bosses"].set_point_disabled(point_index, false)
		astar_nodes_cache[map_name]["dynamic_obstacles_bosses"].clear()
	
	map_name = ""
	
	print("PATHFINDING_SERVICE: Cleaned")


# Method to generate pathes in background
func generate_pathes():
	while can_generate_pathes:
		if should_generate_pathes == true:
			
			# Check which mobs need new path
			var enemies = get_tree().get_nodes_in_group("Enemy")
			var bosses = get_tree().get_nodes_in_group("Boss")
			var ambient_mobs = get_tree().get_nodes_in_group("Ambient Mob")
			if mobs_to_update.size() > 0:
				mobs_to_update.clear()
			
			if enemies.size() > 0:
				enemies_to_update.clear()
				for enemy in enemies:
					if Utils.is_node_valid(enemy):
						# Check if enemy needs new path and pathfinder is not waiting for mob to return new target position
						if enemy.mob_need_path and not mobs_waiting.has(enemy):
							enemies_to_update.append(enemy)
						# Check if enemy need to know if player is reachable
						if enemy.check_can_reach_player:
							mobs_check_can_reach_player.append(enemy)
				if enemies_to_update.size() > 0:
					mobs_to_update["enemies"] = enemies_to_update
			
			if bosses.size() > 0:
				bosses_to_update.clear()
				for boss in bosses:
					if Utils.is_node_valid(boss):
						# Check if boss needs new path and pathfinder is not waiting for boss to return new target position
						if boss.mob_need_path and not bosses_waiting.has(boss):
							bosses_to_update.append(boss)
						# Check if boss need to know if player is reachable
						if boss.check_can_reach_player:
							mobs_check_can_reach_player.append(boss)
				if bosses_to_update.size() > 0:
					mobs_to_update["bosses"] = bosses_to_update
			
			if ambient_mobs.size() > 0:
				ambient_mobs_to_update.clear()
				for ambient_mob in ambient_mobs:
					if Utils.is_node_valid(ambient_mob):
						if ambient_mob.mob_need_path:
							ambient_mobs_to_update.append(ambient_mob)
				if ambient_mobs_to_update.size() > 0:
					mobs_to_update["ambient_mobs"] = ambient_mobs_to_update
			
			
			# Get new positions for mobs
			if mobs_to_update.size() > 0:
				for mob_key in mobs_to_update.keys():
					# Notify ENEMIES that new end_position is needed
					if "enemies" == mob_key:
						var enemies_which_need_new_path = mobs_to_update[mob_key]
						for enemy in enemies_which_need_new_path:
							if Utils.is_node_valid(enemy):
								enemy.get_target_position()
								mobs_waiting.append(enemy)
					
					
					# Notify BOSSES that new end_position is needed
					elif "bosses" == mob_key:
						var bosses_which_need_new_path = mobs_to_update[mob_key]
						for boss in bosses_which_need_new_path:
							if Utils.is_node_valid(boss):
								boss.get_target_position()
								bosses_waiting.append(boss)
					
					
					# Notify AMBIENT_MOB that new end_position is needed
					elif "ambient_mobs" == mob_key:
						var ambient_mob_which_need_new_path = mobs_to_update[mob_key]
						for ambient_mob in ambient_mob_which_need_new_path:
							ambientMobsNavigationTileMap_mutex.lock()
							if Utils.is_node_valid(ambient_mob) and Utils.is_node_valid(ambientMobsNavigationTileMap):
								var target_pos = ambient_mob.get_target_position()
								if target_pos == null:
									# If target_pos is null then take last position of ambient_mob
									target_pos = ambient_mob.global_position
								
								var new_path = get_ambient_mob_astar_path(ambient_mob.global_position, target_pos)
								send_path_to_mob(ambient_mob, new_path)
							ambientMobsNavigationTileMap_mutex.unlock()
			
			
			# Mobs which need to know if they can reach player
			if mobs_check_can_reach_player.size() > 0:
				for mob in mobs_check_can_reach_player:
					if Utils.is_node_valid(mob) and Utils.is_node_valid(Utils.get_current_player()):
						var new_path = get_boss_astar_path(mob.global_position, Utils.get_current_player().global_position)
						if new_path.size() == 0:
							# Mob can reach player
							inform_mob_about_reachable(mob, false, new_path)
						else:
							# Mob can't reach player
							inform_mob_about_reachable(mob, true, new_path)
				# Remove mobs from mobs_check_can_reach_player list
				mobs_check_can_reach_player.clear()
			
			
			# Get path for MOB which got new end_position
			mobs_with_new_position_mutex.lock()
			if mobs_with_new_position.size() > 0:
				for mob in mobs_with_new_position.keys():
					if Utils.is_node_valid(mob):
						var new_path = get_mob_astar_path(mob.global_position, mobs_with_new_position[mob])
						send_path_to_mob(mob, new_path)
						var _was_present = mobs_with_new_position.erase(mob)
			mobs_with_new_position_mutex.unlock()
			
			# Get path for BOSS which got new end_position
			bosses_with_new_position_mutex.lock()
			if bosses_with_new_position.size() > 0:
				for boss in bosses_with_new_position.keys():
					if Utils.is_node_valid(boss):
						var new_path = get_boss_astar_path(boss.global_position, bosses_with_new_position[boss])
						send_path_to_boss(boss, new_path)
						var _was_present = bosses_with_new_position.erase(boss)
			bosses_with_new_position_mutex.unlock()


# Method to send new path to mob
func send_path_to_mob(mob, new_path):
	if can_generate_pathes:
		if Utils.is_node_valid(mob): # Because scene could be change and/or mob is despawned meanwhile
			# Send new path to mob
			mob.call_deferred("update_path", new_path)
			
			# Remove mob from waiting list
			if mobs_waiting.find(mob) != -1:
				mobs_waiting.remove(mobs_waiting.find(mob))


# Method to send new path to mob
func send_path_to_boss(boss, new_path):
	if can_generate_pathes:
		if Utils.is_node_valid(boss): # Because scene could be change and/or mob is despawned meanwhile
			# Send new path to mob
			boss.call_deferred("update_path", new_path)
			
			# Remove mob from waiting list
			if bosses_waiting.find(boss) != -1:
				bosses_waiting.remove(bosses_waiting.find(boss))


# Method is called when thread finished
func clean_thread():
	# Wait for thread to finish
	pathfinder_thread.wait_to_finish()


# Loops through all cells within the map's bounds and
# adds all points to the astar_nodes_cache[current_map_name]["mobs"], except the obstacles.
# Called from another thread
func astar_add_walkable_cells_for_mobs(astar_node_points_dic, current_map_name):
	astar_nodes_cache[current_map_name]["mobs_mutex"].lock()
	for point in astar_node_points_dic.keys():
		var point_index = astar_node_points_dic[point]["point_index"]
		astar_nodes_cache[current_map_name]["mobs"].add_point(point_index, Vector3(point.x, point.y, 0.0))
		
		# Check if preload is canceled
		if preload_stopped:
			break
	astar_nodes_cache[current_map_name]["mobs_mutex"].unlock()


# Loops through all cells within the map's bounds and
# adds all points to the astar_nodes_cache[current_map_name]["mobs"], except the obstacles.
# Called from another thread
func astar_add_walkable_cells_for_bosses(astar_node_points_dic, current_map_name):
	astar_nodes_cache[current_map_name]["bosses_mutex"].lock()
	for point in astar_node_points_dic.keys():
		var point_index = astar_node_points_dic[point]["point_index"]
		astar_nodes_cache[current_map_name]["bosses"].add_point(point_index, Vector3(point.x, point.y, 0.0))
		
		# Check if preload is canceled
		if preload_stopped:
			break
	astar_nodes_cache[current_map_name]["bosses_mutex"].unlock()


# Loops through all cells within the map's bounds and
# adds all points to the astar_nodes_cache[current_map_name]["ambient_mobs"], except the obstacles.
# Called from another thread
func astar_add_walkable_cells_for_ambient_mobs(astar_node_points_dic, current_map_name):
	astar_nodes_cache[current_map_name]["ambient_mobs_mutex"].lock()
	for point in astar_node_points_dic.keys():
		var point_index = astar_node_points_dic[point]["point_index"]
		astar_nodes_cache[current_map_name]["ambient_mobs"].add_point(point_index, Vector3(point.x, point.y, 0.0))
		
		# Check if preload is canceled
		if preload_stopped:
			break
	astar_nodes_cache[current_map_name]["ambient_mobs_mutex"].unlock()


# After added all points to the astar_nodes_cache[current_map_name]["mobs"], connect them
# Called from another thread
func astar_connect_walkable_cells_for_mobs(astar_node_points_dic, current_map_name):
	astar_nodes_cache[current_map_name]["mobs_mutex"].lock()
	for point in astar_node_points_dic.keys():
		var point_index = astar_node_points_dic[point]["point_index"]
		var point_connections = astar_node_points_dic[point]["connections"]
		for point_connection in point_connections:
			astar_nodes_cache[current_map_name]["mobs"].connect_points(point_index, point_connection, false) # False means it is one-way / not bilateral
		
		# Check if preload is canceled
		if preload_stopped:
			break
	astar_nodes_cache[current_map_name]["mobs_mutex"].unlock()


# After added all points to the astar_nodes_cache[current_map_name]["mobs"], connect them
# Called from another thread
func astar_connect_walkable_cells_for_bosses(astar_node_points_dic, current_map_name):
	astar_nodes_cache[current_map_name]["bosses_mutex"].lock()
	for point in astar_node_points_dic.keys():
		var point_index = astar_node_points_dic[point]["point_index"]
		var point_connections = astar_node_points_dic[point]["connections"]
		for point_connection in point_connections:
			astar_nodes_cache[current_map_name]["bosses"].connect_points(point_index, point_connection, false) # False means it is one-way / not bilateral
		
		# Check if preload is canceled
		if preload_stopped:
			break
	astar_nodes_cache[current_map_name]["bosses_mutex"].unlock()


# After added all points to the astar_nodes_cache[current_map_name]["ambient_mobs"], connect them
# Called from another thread
func astar_connect_walkable_cells_for_ambient_mobs(astar_node_points_dic, current_map_name):
	astar_nodes_cache[current_map_name]["ambient_mobs_mutex"].lock()
	for point in astar_node_points_dic.keys():
		var point_index = astar_node_points_dic[point]["point_index"]
		var point_connections = astar_node_points_dic[point]["connections"]
		for point_connection in point_connections:
			astar_nodes_cache[current_map_name]["ambient_mobs"].connect_points(point_index, point_connection, false) # False means it is one-way / not bilateral
		
		# Check if preload is canceled
		if preload_stopped:
			break
	astar_nodes_cache[current_map_name]["ambient_mobs_mutex"].unlock()


# Method calculates the index of the point in astar_nodes - INPUT: Tilecoords like (-272, -144) or (128, 64)
func calculate_point_index(point):
	# Points are from (-272, -144) to (128, 64)
	# Make them to (0, 0) to (400, 208)
	point -= map_offset_in_tiles * 2
	
	return point.x + map_size_in_tiles.x * 2 * point.y


# Generates and returns path for the given positions
func get_mob_astar_path(mob_start, mob_end):
	var time_start = OS.get_system_time_msecs()
	var time_now = 0
	var dic = {}
	
	# Get position in map and get point index in astar_nodes_cache[map_name]["mobs"]
	var path_start_tile_position = world_to_tile_coords(mob_start)
	var path_end_tile_position = world_to_tile_coords(mob_end)
	var start_point_index = calculate_point_index(path_start_tile_position)
	var end_point_index = calculate_point_index(path_end_tile_position)
	
	
	astar_nodes_cache[map_name]["mobs_mutex"].lock()
	
	# Check if start_position is valid - else take nearest & valid point to the invalid point
	if not astar_nodes_cache[map_name]["mobs"].has_point(start_point_index):
		start_point_index = astar_nodes_cache[map_name]["mobs"].get_closest_point(Vector3(path_start_tile_position.x, path_start_tile_position.y, 0), false)
	
	# Check if end position is valid / reachable - else take nearest & valid point to the invalid point
	if not astar_nodes_cache[map_name]["mobs"].has_point(end_point_index):
		end_point_index = astar_nodes_cache[map_name]["mobs"].get_closest_point(Vector3(path_end_tile_position.x, path_end_tile_position.y, 0), false)
	
#	time_now = OS.get_system_time_msecs()
#	var time_elapsed = time_now - time_start
#	dic["start"] = time_elapsed
#	time_start = OS.get_system_time_msecs()
	
	# Check if point is disabled -> take nearest & enabled point to the disabled point
	if astar_nodes_cache[map_name]["mobs"].has_point(start_point_index) and astar_nodes_cache[map_name]["mobs"].is_point_disabled(start_point_index):
		start_point_index = astar_nodes_cache[map_name]["mobs"].get_closest_point(Vector3(path_start_tile_position.x, path_start_tile_position.y, 0), false)
	if astar_nodes_cache[map_name]["mobs"].has_point(end_point_index) and astar_nodes_cache[map_name]["mobs"].is_point_disabled(end_point_index):
		end_point_index = astar_nodes_cache[map_name]["mobs"].get_closest_point(Vector3(path_end_tile_position.x, path_end_tile_position.y, 0), false)
	
	# Get the path as an array of points from astar_nodes_cache[map_name]["mobs"]
	var point_path = astar_nodes_cache[map_name]["mobs"].get_point_path(start_point_index, end_point_index) # !!! TAKES LONG TIME!!!!!!!! 73217 57269
	
	astar_nodes_cache[map_name]["mobs_mutex"].unlock()
	
	
	# Get time to calculate path
	time_now = OS.get_system_time_msecs()
	var time_elapsed = time_now - time_start
	dic["get_point_path"] = time_elapsed
#	time_start = OS.get_system_time_msecs()
	
	if point_path.size() != 0:
		# Remove the position in index 0 because this is the starting cell
		point_path.remove(0)

		
		# Convert point to map positions
		var path_world = []
		for point in point_path:
			var point_world = point_coords_world(Vector2(point.x, point.y))
			path_world.append(point_world)
		
	#	time_now = OS.get_system_time_msecs()
	#	time_elapsed = time_now - time_start
	#	dic["rest"] = time_elapsed
		
		# Return path
		return path_world
	
	else:
#		printerr("ERROR: \"get_mob_astar_path\" NO PATH AVAILABLE")
		return []


# Generates and returns path for the given positions
func get_boss_astar_path(boss_start, boss_end):
	# Get position in map and get point index in astar_nodes_cache[map_name]["bosses"]
	var path_start_tile_position = world_to_tile_coords(boss_start)
	var path_end_tile_position = world_to_tile_coords(boss_end)
	var start_point_index = calculate_point_index(path_start_tile_position)
	var end_point_index = calculate_point_index(path_end_tile_position)
	
	
	astar_nodes_cache[map_name]["bosses_mutex"].lock()
	
	# Check if start_position is valid - else take nearest & valid point to the invalid point
	if not astar_nodes_cache[map_name]["bosses"].has_point(start_point_index):
		start_point_index = astar_nodes_cache[map_name]["bosses"].get_closest_point(Vector3(path_start_tile_position.x, path_start_tile_position.y, 0), false)
	
	# Check if end position is valid / reachable - else take nearest & valid point to the invalid point
	if not astar_nodes_cache[map_name]["bosses"].has_point(end_point_index):
		end_point_index = astar_nodes_cache[map_name]["bosses"].get_closest_point(Vector3(path_end_tile_position.x, path_end_tile_position.y, 0), false)
	
	# Check if point is disabled -> take nearest & enabled point to the disabled point
	if astar_nodes_cache[map_name]["bosses"].has_point(start_point_index) and astar_nodes_cache[map_name]["bosses"].is_point_disabled(start_point_index):
		start_point_index = astar_nodes_cache[map_name]["bosses"].get_closest_point(Vector3(path_start_tile_position.x, path_start_tile_position.y, 0), false)
	if astar_nodes_cache[map_name]["bosses"].has_point(end_point_index) and astar_nodes_cache[map_name]["bosses"].is_point_disabled(end_point_index):
		end_point_index = astar_nodes_cache[map_name]["bosses"].get_closest_point(Vector3(path_end_tile_position.x, path_end_tile_position.y, 0), false)
	
	# Get the path as an array of points from astar_nodes_cache[map_name]["bosses"]
	var point_path = astar_nodes_cache[map_name]["bosses"].get_point_path(start_point_index, end_point_index) # !!! TAKES LONG TIME!!!!!!!! 73217 57269
	
	astar_nodes_cache[map_name]["bosses_mutex"].unlock()
	
	if point_path.size() != 0:
		# Remove the position in index 0 because this is the starting cell
		point_path.remove(0)
		
		# Convert point to map positions
		var path_world = []
		for point in point_path:
			var point_world = point_coords_world(Vector2(point.x, point.y))
			path_world.append(point_world)
		
		# Return path
		return path_world
	
	else:
#		printerr("ERROR: \"get_boss_astar_path\" NO PATH AVAILABLE")
		return []


# Method to generate global_position to tile_coord
func world_to_tile_coords(global_position : Vector2) -> Vector2:
	var point = Vector2.ZERO
	point.x = floor(global_position.x / (float(Constants.TILE_SIZE) / (Constants.POINTS_HORIZONTAL_PER_TILE - 1)))
	point.y = floor(global_position.y / (float(Constants.TILE_SIZE) / (Constants.POINTS_VERTICAL_PER_TILE - 1)))
	
	return point


# Method to generate tile_coord to global_position
func point_coords_world(tile_coords : Vector2) -> Vector2:
	var global_position = Vector2.ZERO
	global_position.x = tile_coords.x * (float(Constants.TILE_SIZE) / (Constants.POINTS_HORIZONTAL_PER_TILE - 1))
	global_position.y = tile_coords.y * (float(Constants.TILE_SIZE) / (Constants.POINTS_VERTICAL_PER_TILE - 1))
	
	return global_position


# Generates and returns path for the given positions
func get_ambient_mob_astar_path(mob_start, mob_end):
	# Get position in map and get point index in astar_nodes_cache[map_name]["ambient_mobs"]
	ambientMobsNavigationTileMap_mutex.lock()
	var path_start_tile_position = ambientMobsNavigationTileMap.world_to_map(mob_start)
	var path_end_tile_position = ambientMobsNavigationTileMap.world_to_map(mob_end)
	ambientMobsNavigationTileMap_mutex.unlock()
	var start_point_index = calculate_point_index(path_start_tile_position)
	var end_point_index = calculate_point_index(path_end_tile_position)
	
	
	astar_nodes_cache[map_name]["ambient_mobs_mutex"].lock()
	
	# Check if start_position is valid - else take nearest & valid point to the invalid point
	if not astar_nodes_cache[map_name]["ambient_mobs"].has_point(start_point_index):
		start_point_index = astar_nodes_cache[map_name]["ambient_mobs"].get_closest_point(Vector3(path_start_tile_position.x, path_start_tile_position.y, 0), false)
	
	# Check if end position is valid / reachable - else take nearest & valid point to the invalid point
	if not astar_nodes_cache[map_name]["ambient_mobs"].has_point(end_point_index):
		end_point_index = astar_nodes_cache[map_name]["ambient_mobs"].get_closest_point(Vector3(path_end_tile_position.x, path_end_tile_position.y, 0), false)
	
	# Get the path as an array of points from astar_nodes_cache[map_name]["ambient_mobs"]
	var point_path = astar_nodes_cache[map_name]["ambient_mobs"].get_point_path(start_point_index, end_point_index)
	
	astar_nodes_cache[map_name]["ambient_mobs_mutex"].unlock()
	
	if point_path.size() != 0:
		# Remove the position in index 0 because this is the starting cell
		point_path.remove(0)
		
		# Convert point to map positions
		var path_world = []
		ambientMobsNavigationTileMap_mutex.lock()
		for point in point_path:
			var point_world = ambientMobsNavigationTileMap.map_to_world(Vector2(point.x, point.y)) + half_cell_size
			path_world.append(point_world)
		ambientMobsNavigationTileMap_mutex.unlock()
		# Return path
		return path_world
	
	else:
		printerr("ERROR: \"get_ambient_mob_astar_path\" NO PATH AVAILABLE")
		return []


# Method to disable points within the collisionshape FOR MOBS
# Called from another thread but with call_deferred so this method is executed in this thread
func add_dynamic_obstacle(collisionshape_node : CollisionShape2D, position):
	astar_nodes_cache[map_name]["dynamic_obstacles_mobs_mutex"].lock()
	astar_nodes_cache[map_name]["dynamic_obstacles_bosses_mutex"].lock()
	astar_nodes_cache[map_name]["mobs_mutex"].lock()
	astar_nodes_cache[map_name]["bosses_mutex"].lock()
	
	astar_nodes_cache[map_name]["dynamic_obstacles_mobs"][collisionshape_node.get_instance_id()] = []
	astar_nodes_cache[map_name]["dynamic_obstacles_bosses"][collisionshape_node.get_instance_id()] = []
	var xExtentsFactor = 2
	var yExtentsFactor = 2
	var size_x = ceil(collisionshape_node.shape.extents.x * xExtentsFactor)
	var size_y = ceil(collisionshape_node.shape.extents.y * yExtentsFactor)
	
	# Add obstacle for mobs
	# Top left point
	var top_left_position = position
	var top_left_point = world_to_tile_coords(top_left_position)
	var top_left_point_index = calculate_point_index(top_left_point)
	if astar_nodes_cache[map_name]["mobs"].has_point(top_left_point_index):
		astar_nodes_cache[map_name]["dynamic_obstacles_mobs"][collisionshape_node.get_instance_id()].append(top_left_point_index)
		astar_nodes_cache[map_name]["mobs"].set_point_disabled(top_left_point_index, true)
	
	# Bottom right point
	var bottom_right_position = Vector2(position.x + size_x + Constants.POINT_SIZE_IN_PIXEL_PER_TILE, position.y + size_y + Constants.POINT_SIZE_IN_PIXEL_PER_TILE) # Add here POINT_SIZE_IN_PIXEL_PER_TILE because point is top left of point area. Extend because of bottom right
	var bottom_right_point = world_to_tile_coords(bottom_right_position)
	var bottom_right_point_index = calculate_point_index(bottom_right_point)
	if astar_nodes_cache[map_name]["mobs"].has_point(bottom_right_point_index):
		astar_nodes_cache[map_name]["dynamic_obstacles_mobs"][collisionshape_node.get_instance_id()].append(bottom_right_point_index)
		astar_nodes_cache[map_name]["mobs"].set_point_disabled(bottom_right_point_index, true)
	
	# Get all points between top_left_point and bottom_right_point
	var horizontal_point_span = bottom_right_point.x - top_left_point.x + 1
	var vertical_point_span = bottom_right_point.y - top_left_point.y + 1
	for x in horizontal_point_span:
		for y in vertical_point_span:
			var current_point = top_left_point + Vector2(x, y)
			var current_point_index = calculate_point_index(current_point)
			if astar_nodes_cache[map_name]["mobs"].has_point(current_point_index) and not astar_nodes_cache[map_name]["dynamic_obstacles_mobs"][collisionshape_node.get_instance_id()].has(current_point_index):
				astar_nodes_cache[map_name]["dynamic_obstacles_mobs"][collisionshape_node.get_instance_id()].append(current_point_index)
				astar_nodes_cache[map_name]["mobs"].set_point_disabled(current_point_index, true)
	
	
	# Add obstacle for bosses
	# Top left point
	var boss_safety_space = 2 * Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
	top_left_position = position - boss_safety_space
	top_left_point = world_to_tile_coords(top_left_position)
	top_left_point_index = calculate_point_index(top_left_point)
	if astar_nodes_cache[map_name]["bosses"].has_point(top_left_point_index):
		astar_nodes_cache[map_name]["dynamic_obstacles_bosses"][collisionshape_node.get_instance_id()].append(top_left_point_index)
		astar_nodes_cache[map_name]["bosses"].set_point_disabled(top_left_point_index, true)
	
	# Bottom right point
	bottom_right_position = Vector2(position.x + size_x + Constants.POINT_SIZE_IN_PIXEL_PER_TILE, position.y + size_y + Constants.POINT_SIZE_IN_PIXEL_PER_TILE) + boss_safety_space # Add here POINT_SIZE_IN_PIXEL_PER_TILE because point is top left of point area. Extend because of bottom right
	bottom_right_point = world_to_tile_coords(bottom_right_position)
	bottom_right_point_index = calculate_point_index(bottom_right_point)
	if astar_nodes_cache[map_name]["bosses"].has_point(bottom_right_point_index):
		astar_nodes_cache[map_name]["dynamic_obstacles_bosses"][collisionshape_node.get_instance_id()].append(bottom_right_point_index)
		astar_nodes_cache[map_name]["bosses"].set_point_disabled(bottom_right_point_index, true)
	
	# Get all points between top_left_point and bottom_right_point
	horizontal_point_span = bottom_right_point.x - top_left_point.x + 1
	vertical_point_span = bottom_right_point.y - top_left_point.y + 1
	for x in horizontal_point_span:
		for y in vertical_point_span:
			var current_point = top_left_point + Vector2(x, y)
			var current_point_index = calculate_point_index(current_point)
			if astar_nodes_cache[map_name]["bosses"].has_point(current_point_index) and not astar_nodes_cache[map_name]["dynamic_obstacles_bosses"][collisionshape_node.get_instance_id()].has(current_point_index):
				astar_nodes_cache[map_name]["dynamic_obstacles_bosses"][collisionshape_node.get_instance_id()].append(current_point_index)
				astar_nodes_cache[map_name]["bosses"].set_point_disabled(current_point_index, true)
	
	# Update obstacles visual
	if Constants.CAN_DEBUG and Constants.SHOW_PATHFINDING_POINTS:
		if astar2DVisualizerNode != null:
			astar2DVisualizerNode.call_deferred("update_disabled_points")
	
	astar_nodes_cache[map_name]["dynamic_obstacles_mobs_mutex"].unlock()
	astar_nodes_cache[map_name]["dynamic_obstacles_bosses_mutex"].unlock()
	astar_nodes_cache[map_name]["mobs_mutex"].unlock()
	astar_nodes_cache[map_name]["bosses_mutex"].unlock()


# Method to remove dynamic obstacle from astar
# Called from another thread but with call_deferred so this method is executed in this thread
func remove_dynamic_obstacle(collisionshape_node : CollisionShape2D):
	astar_nodes_cache[map_name]["dynamic_obstacles_mobs_mutex"].lock()
	astar_nodes_cache[map_name]["dynamic_obstacles_bosses_mutex"].lock()
	astar_nodes_cache[map_name]["mobs_mutex"].lock()
	astar_nodes_cache[map_name]["bosses_mutex"].lock()
	
	var disabled_mob_points = astar_nodes_cache[map_name]["dynamic_obstacles_mobs"][collisionshape_node.get_instance_id()]
	var disabled_boss_points = astar_nodes_cache[map_name]["dynamic_obstacles_bosses"][collisionshape_node.get_instance_id()]
	
	# Enable points for MOBS
	for disabled_point in disabled_mob_points:
		astar_nodes_cache[map_name]["mobs"].set_point_disabled(disabled_point, false)
	# Delete obstacle from dic
	astar_nodes_cache[map_name]["dynamic_obstacles_mobs"].erase(collisionshape_node.get_instance_id())
	
	# Enable points for BOSSES
	for disabled_point in disabled_boss_points:
		astar_nodes_cache[map_name]["bosses"].set_point_disabled(disabled_point, false)
	# Delete obstacle from dic
	astar_nodes_cache[map_name]["dynamic_obstacles_bosses"].erase(collisionshape_node.get_instance_id())
	
	# Update obstacles visual
	if Constants.CAN_DEBUG and Constants.SHOW_PATHFINDING_POINTS:
		if astar2DVisualizerNode != null:
			astar2DVisualizerNode.call_deferred("update_disabled_points")
	
	astar_nodes_cache[map_name]["dynamic_obstacles_mobs_mutex"].unlock()
	astar_nodes_cache[map_name]["dynamic_obstacles_bosses_mutex"].unlock()
	astar_nodes_cache[map_name]["mobs_mutex"].unlock()
	astar_nodes_cache[map_name]["bosses_mutex"].unlock()


# New position for MOB has arrived
# Called from another thread but with call_deferred so this method is executed in this thread
func got_mob_position(mob, position):
	mobs_with_new_position_mutex.lock()
	if Utils.is_node_valid(mob):
		mobs_with_new_position[mob] = position
	mobs_with_new_position_mutex.unlock()


# New position for BOSS has arrived
# Called from another thread but with call_deferred so this method is executed in this thread
func got_boss_position(boss, position):
	bosses_with_new_position_mutex.lock()
	if Utils.is_node_valid(boss):
		bosses_with_new_position[boss] = position
	bosses_with_new_position_mutex.unlock()


# Inform mob about reachability of player
func inform_mob_about_reachable(mob, can_reach, reachable_path):
	if Utils.is_node_valid(mob):
		# Send reachability of player to mob
		mob.call_deferred("can_reach_player", can_reach, reachable_path)
