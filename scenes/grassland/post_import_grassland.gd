extends Node

const CONSTANTS = preload("res://autoload/Constants.gd")
const CUSTOM_LIGHT = preload("res://scenes/light/CustomLight.tscn")
const VILLAGE_ANIMATED_DOORS_TILESET = preload("res://assets/tilesets/Village Animated Doors.png")


var compressed_tilemap = TileMap.new()
var mobs_nav_tilemap = TileMap.new()
var ambient_mobs_nav_tilemap = TileMap.new()

var chunk_size = CONSTANTS.CHUNK_SIZE_TILES # Chunk tiles width/height in tiles
var map_min_pos = Vector2.ZERO # In tiles
var map_max_pos = Vector2.ZERO # In tiles
var map_min_global_pos = Vector2.ZERO # In pixel
var map_offset_in_tiles = Vector2.ZERO # In tiles
var map_size_in_tiles = Vector2.ZERO # In tiles


# Method to change the scene directly after it is imported by Tiled Map Importer
func post_import(scene):
	print("POST_IMPORT_GRASSLAND: Reimporte " + scene.name + "...")
	
	# Set lights with script to lightsObject
	var lightsObject = scene.find_node("lights")
	if lightsObject != null and lightsObject.get_children().size() > 0:
		for child in lightsObject.get_children():
			if child is Sprite:
				var sprite_positon = child.position
				var custom_light = CUSTOM_LIGHT.instance()
				custom_light.position = sprite_positon
				custom_light.radius = 64
				var sprite = custom_light.get_node("Sprite")
				sprite.texture = child.texture
				
				# Set custom_light to node/replace existing sprite
				child.replace_by(custom_light, true)
				custom_light.set_owner(scene)
				for child_in_light in custom_light.get_children():
					child_in_light.set_owner(scene)
	
	
	# Set lights to windows with script
	var windows_positions = scene.find_node("windows_positions")
	if windows_positions != null and windows_positions.get_children().size() > 0:
		for child in windows_positions.get_children():
			if child is Position2D:
				var custom_light = CUSTOM_LIGHT.instance()
				# Position
				# If child is WINDOW
				if child.get_node_or_null("Sprite") == null:
					var light_position = custom_light.get_node("LightPosition")
					custom_light.position = child.position - light_position.position
				# If child is NORMAL LIGHT
				else:
					custom_light.position = child.position
				
				if child.get_meta("big_window"):
					custom_light.radius = 8
				else:
					custom_light.radius = 5
				var sprite = custom_light.get_node("Sprite")
				custom_light.remove_child(sprite)
				
				# Set custom_light to node/replace existing sprite
				child.replace_by(custom_light, true)
				custom_light.set_owner(scene)
				for child_in_light in custom_light.get_children():
					child_in_light.set_owner(scene)
	
	
	# Compress all tilemaps to one - direct before creating navigation and after adding custom nodes with collision on ground
	compress_tilemaps(scene)
	# Add navigation tilemap for mobs
	# Get TileSet from other TileMap because of changing tileset ids "res://assets/map/map_grassland.tmx::5195" -> 5195
	# Also in every TileMap all TileSets are stored
	var dirtLvl0TileMap : TileMap = scene.find_node("dirt lvl0")
	mobs_nav_tilemap = compressed_tilemap.duplicate()
	mobs_nav_tilemap.tile_set = dirtLvl0TileMap.tile_set
	mobs_nav_tilemap.cell_quadrant_size = 1
	mobs_nav_tilemap.cell_y_sort = false
	mobs_nav_tilemap.cell_clip_uv = true
	mobs_nav_tilemap.cell_size = Vector2(16,16)
	mobs_nav_tilemap.name = "mobs_navigation_tilemap"
	mobs_nav_tilemap.visible = false
	
	# merge all tilemaps and collisionshapes from "ground" together
	remove_collisionshapes_from_not_dynamic_objects_from_tilemap(mobs_nav_tilemap, scene.find_node("ground"))
	remove_collisiontiles_from_tilemap(mobs_nav_tilemap)
	
	# Setup NavigationTileMap for mobs
	var navigation : Node2D = scene.find_node("navigation")
	navigation.name = "mobs_navigation"
	navigation.visible = false
	navigation.add_child(mobs_nav_tilemap)
	mobs_nav_tilemap.set_owner(scene)
	
	
	
	# Add navigation tilemap for ambient_mobs
	# Get TileSet from other TileMap because of changing tileset ids "res://assets/map/map_grassland.tmx::5195" -> 5195
	# Also in every TileMap all TileSets are stored
	ambient_mobs_nav_tilemap = compressed_tilemap.duplicate()
	ambient_mobs_nav_tilemap.tile_set = dirtLvl0TileMap.tile_set
	ambient_mobs_nav_tilemap.cell_quadrant_size = 1
	ambient_mobs_nav_tilemap.cell_y_sort = false
	ambient_mobs_nav_tilemap.cell_clip_uv = true
	ambient_mobs_nav_tilemap.cell_size = Vector2(16,16)
	ambient_mobs_nav_tilemap.name = "ambient_mobs_navigation_tilemap"
	ambient_mobs_nav_tilemap.visible = false
	
	# Setup Navigation2D for ambient mobs
	var ambient_mobs_navigation : Node2D = scene.find_node("ambientMobs navigation")
	ambient_mobs_navigation.name = "ambient_mobs_navigation"
	ambient_mobs_navigation.visible = false
	ambient_mobs_navigation.add_child(ambient_mobs_nav_tilemap)
	ambient_mobs_nav_tilemap.set_owner(scene)
	
	
	
	# Add collision polygon to area2d for ambient mobs
	var ambient_mobs_polygon_area_instance = Area2D.new()
	ambient_mobs_polygon_area_instance.monitoring = false
	ambient_mobs_polygon_area_instance.monitorable = false
	ambient_mobs_polygon_area_instance.set_collision_layer_bit(0, false)
	ambient_mobs_polygon_area_instance.set_collision_mask_bit(0, false)
	ambient_mobs_navigation.add_child(ambient_mobs_polygon_area_instance)
	ambient_mobs_polygon_area_instance.set_owner(scene)
	
	var ambient_mobs_polygon = CollisionPolygon2D.new()
	ambient_mobs_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	ambient_mobs_polygon.disabled = true
	
	var tile_polygon = PoolVector2Array()
	var rec = compressed_tilemap.get_used_rect()
	
	var topleft = rec.position * 16
	var topright = Vector2(rec.end.x, rec.position.y) * 16
	var bottomleft = Vector2(rec.position.x, rec.end.y) * 16
	var bottomright = Vector2(rec.end.x, rec.end.y) * 16
	tile_polygon.append(topleft)
	tile_polygon.append(topright)
	tile_polygon.append(bottomright)
	tile_polygon.append(bottomleft)
	ambient_mobs_polygon.polygon = tile_polygon
	ambient_mobs_polygon_area_instance.add_child(ambient_mobs_polygon)
	ambient_mobs_polygon.set_owner(scene)
	
	
	# Setup entitylayer to YSorts
	var entitylayer : Node2D = scene.find_node("entitylayer")
	var ySortEntities = YSort.new()
	ySortEntities.name = entitylayer.name
	entitylayer.replace_by(ySortEntities, true)
	# Setup playerlayer
	var playerlayer : Node2D = scene.find_node("playerlayer")
	var ySortPlayer = YSort.new()
	ySortPlayer.name = playerlayer.name
	playerlayer.replace_by(ySortPlayer, true)
	# Setup mobslayer
	var mobslayer : Node2D = scene.find_node("mobslayer")
	var ySortMobs = YSort.new()
	ySortMobs.name = mobslayer.name
	mobslayer.replace_by(ySortMobs, true)
	# Setup lootlayer
	var lootlayer : Node2D = scene.find_node("lootLayer")
	var ySortLoot = YSort.new()
	ySortLoot.name = lootlayer.name
	lootlayer.replace_by(ySortLoot, true)
	# Setup npclayer
	var npclayer : Node2D = scene.find_node("npclayer")
	var ySortNPCS = YSort.new()
	ySortNPCS.name = npclayer.name
	npclayer.replace_by(ySortNPCS, true)
	
	
	# Setup all doors with animation
	var doorsObject = scene.find_node("doors")
	if doorsObject != null and doorsObject.get_children().size() > 0:
		for child in doorsObject.get_children():
			if "door_" in child.name:
				var selected_door_sprite = child.get_meta("selected_door_sprite") # possible slected doors = 1,2,3,4,6,7,8,9,11,12,13,14,16,17,18,19,24,29
				var frame = selected_door_sprite * 4 - 4
				var sprite = Sprite.new()
				sprite.name = "sprite"
				sprite.centered = false
				sprite.texture = VILLAGE_ANIMATED_DOORS_TILESET
				sprite.hframes = 20
				sprite.vframes = 8
				sprite.frame = frame
				sprite.position = child.position
				sprite.position.y = sprite.position.y + sprite.texture.get_size().y / sprite.vframes
				
				sprite.offset = Vector2(0, -sprite.texture.get_size().y / sprite.vframes)
				
				doorsObject.add_child(sprite)
				sprite.set_owner(scene)
				
				var animationPlayer = AnimationPlayer.new()
				animationPlayer.name = "animationPlayer"
				var path = "../" + sprite.name + ":frame"
				
				var idleDoorAnimation = Animation.new()
				animationPlayer.add_animation( "idleDoor", idleDoorAnimation)
				idleDoorAnimation.add_track(0)
				idleDoorAnimation.length = 0.4
				idleDoorAnimation.track_set_path(0, path)
				idleDoorAnimation.track_insert_key(0, 0.0, frame)
				idleDoorAnimation.value_track_set_update_mode(0, Animation.UPDATE_DISCRETE)
				idleDoorAnimation.loop = 0
				
				var openDoorAnimation = Animation.new()
				animationPlayer.add_animation( "openDoor", openDoorAnimation)
				var sprite_track_index = openDoorAnimation.add_track(Animation.TYPE_VALUE)
				openDoorAnimation.length = 0.4
				openDoorAnimation.track_set_path(sprite_track_index, path)
				openDoorAnimation.track_insert_key(sprite_track_index, 0.0, frame)
				openDoorAnimation.track_insert_key(sprite_track_index, 0.1, frame + 1)
				openDoorAnimation.track_insert_key(sprite_track_index, 0.2, frame + 2)
				openDoorAnimation.track_insert_key(sprite_track_index, 0.3, frame + 3)
				openDoorAnimation.value_track_set_update_mode(sprite_track_index, Animation.UPDATE_DISCRETE)
				openDoorAnimation.loop = 0
				var method_track_index = openDoorAnimation.add_track(Animation.TYPE_METHOD)
				var method_path = "../../../../../../.."
				openDoorAnimation.track_set_path(method_track_index, method_path)
				openDoorAnimation.track_insert_key(method_track_index, 0.4, {"args": [], "method": "on_door_opened"})
				
				var closeDoorAnimation = Animation.new()
				animationPlayer.add_animation( "closeDoor", closeDoorAnimation)
				closeDoorAnimation.add_track(Animation.TYPE_VALUE)
				closeDoorAnimation.length = 0.4
				closeDoorAnimation.track_set_path(0, path)
				closeDoorAnimation.track_insert_key(0, 0.0, frame + 3)
				closeDoorAnimation.track_insert_key(0, 0.1, frame + 2)
				closeDoorAnimation.track_insert_key(0, 0.2, frame + 1)
				closeDoorAnimation.track_insert_key(0, 0.3, frame)
				closeDoorAnimation.value_track_set_update_mode(0, Animation.UPDATE_DISCRETE)
				closeDoorAnimation.loop = 0
				
				animationPlayer.current_animation = "idleDoor"
				animationPlayer.autoplay = "idleDoor"
				
				child.add_child(animationPlayer)
				animationPlayer.set_owner(scene)
	
	
	
	# Setup NPC pathes
	var npcPathes = scene.find_node("npcPathes")
	var pathes = []
	for child in npcPathes.get_children():
		var path = child.get_child(0)
		var curve = Curve2D.new()
		for point in path.get_polygon():
			curve.add_point(point)
		var newPath = Path2D.new()
		if child.has_meta("is_circle"):
			var meta = child.get_meta("is_circle")
			newPath.set_meta("is_circle", meta)
		child.remove_child(path)
		newPath.set_curve(curve)
		newPath.name = child.name
		newPath.position = child.position
		pathes.append(newPath)
		npcPathes.remove_child(child)
	for path in pathes:
		npcPathes.add_child(path)
		path.set_owner(scene)
	
	
	
	
	# Setup map - performace optimisation
	iterate_over_nodes(scene)
	
	# generate chunks -> best at the end
	print("POST_IMPORT_GRASSLAND: Generate chunks...")
	generate_chunks(scene)
	print("POST_IMPORT_GRASSLAND: Chunks generated!")
	
	# Create astar pathfinding
	print("POST_IMPORT_GRASSLAND: Generate AStars...")
	create_astar(scene)
	print("POST_IMPORT_GRASSLAND: AStars generated!")
	
	
	# Cleanup scene -> need to be at the end!!
	cleanup_node(scene.find_node("ground"))
	cleanup_node(scene.find_node("higher"))
	print("POST_IMPORT_GRASSLAND: Reimported " + scene.name + "! \n")
	return scene


# Method to create the astar nodes with points and connection -> then saves the dic to file
func create_astar(scene):
	# Create astar
	var astar_nodes_dics = {
							"mobs" : {
								"points": {}
							},
							"bosses" : {
								"points": {}
							},
							"ambient_mobs" : {
								"points": {}
							}
						}
	astar_add_walkable_cells_for_mobs(astar_nodes_dics)
	astar_connect_walkable_cells_for_mobs(astar_nodes_dics)
	print("POST_IMPORT_GRASSLAND: Generated AStar for MOBS!")
	astar_add_walkable_cells_for_bosses(astar_nodes_dics)
	astar_connect_walkable_cells_for_bosses(astar_nodes_dics)
	print("POST_IMPORT_GRASSLAND: Generated AStar for BOSSES!")
	astar_add_walkable_cells_for_ambient_mobs(astar_nodes_dics)
	astar_connect_walkable_cells_for_ambient_mobs(astar_nodes_dics)
	print("POST_IMPORT_GRASSLAND: Generated AStar for AMBIENT_MOBS!")
	
	# Store astar
	# Check if directory is existing
	var dir_game_pathfinding = Directory.new()
	if !dir_game_pathfinding.dir_exists(CONSTANTS.SAVE_GAME_PATHFINDING_PATH):
		dir_game_pathfinding.make_dir(CONSTANTS.SAVE_GAME_PATHFINDING_PATH)
	# Save file
	var astar_save = File.new()
	astar_save.open(CONSTANTS.SAVE_GAME_PATHFINDING_PATH + scene.name + ".sav", File.WRITE)
	astar_save.store_var(astar_nodes_dics)
	astar_save.close()
	print("POST_IMPORT_GRASSLAND: Saved AStars to file!")


# Method to generate chunks in map
func generate_chunks(scene):
	collect_tilemaps(scene.find_node("ground"))
	collect_tilemaps(scene.find_node("higher"))
	
	# Create dublicates to get all tilemaps and objects
	var ground_duplicate = scene.find_node("ground").duplicate()
	var higher_duplicate = scene.find_node("higher").duplicate()
	
	# Map size in tiles
	var map_width = abs(map_min_pos.x) + abs(map_max_pos.x) + 1 # +1 because (0,0)
	var map_height = abs(map_min_pos.y) + abs(map_max_pos.y) + 1 # +1 because (0,0)
	var vertical_chunks_count = ceil(map_height / chunk_size)
	var horizontal_chunks_count = ceil(map_width / chunk_size)
	
	map_size_in_tiles = Vector2(map_width, map_height)
	map_offset_in_tiles = map_min_global_pos / CONSTANTS.TILE_SIZE
	
	# Ground chunks
	var ground_chunks_node = Node2D.new()
	ground_chunks_node.name = "Chunks"
	# Store importent informations in node
	ground_chunks_node.set_meta("vertical_chunks_count", vertical_chunks_count)
	ground_chunks_node.set_meta("horizontal_chunks_count", horizontal_chunks_count)
	ground_chunks_node.set_meta("map_min_global_pos", map_min_global_pos)
	ground_chunks_node.set_meta("map_size_in_tiles", map_size_in_tiles)
	ground_chunks_node.set_meta("map_name", scene.name)
	# Add ground_chunks_node to ground
	scene.find_node("ground").add_child(ground_chunks_node)
	ground_chunks_node.set_owner(scene)
	
	# Higher chunks
	var higher_chunks_node = Node2D.new()
	higher_chunks_node.name = "Chunks"
	# Store importent informations in node
	higher_chunks_node.set_meta("vertical_chunks_count", vertical_chunks_count)
	higher_chunks_node.set_meta("horizontal_chunks_count", horizontal_chunks_count)
	higher_chunks_node.set_meta("map_min_global_pos", map_min_global_pos)
	# Add higher_chunks_node to ground
	scene.find_node("higher").add_child(higher_chunks_node)
	higher_chunks_node.set_owner(scene)
	
	
	# Create ground chunks
	for chunk_y in range(vertical_chunks_count):
		for chunk_x in range(horizontal_chunks_count):
			var min_x = map_min_pos.x + chunk_size * chunk_x
			var min_y = map_min_pos.y + chunk_size * chunk_y
			var max_x = (map_min_pos.x + chunk_size * chunk_x) + chunk_size - 1
			var max_y = (map_min_pos.y + chunk_size * chunk_y) + chunk_size - 1
			var chunk_data = {"chunk_x": chunk_x, "chunk_y": chunk_y, "min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y}

			# Create chunk node
			var chunk_node = Node2D.new()
			chunk_node.name = "Chunk (" + str(chunk_x) + "," + str(chunk_y) + ")"
			chunk_node.visible = false
			ground_chunks_node.add_child(chunk_node)
			chunk_node.set_owner(scene)
			
			# Create chunk with tilemaps and objects
			create_chunk(scene, chunk_data, ground_duplicate, chunk_node, false)
	
	
	# Create higher chunks
	for chunk_y in range(vertical_chunks_count):
		for chunk_x in range(horizontal_chunks_count):
			var min_x = map_min_pos.x + chunk_size * chunk_x
			var min_y = map_min_pos.y + chunk_size * chunk_y
			var max_x = (map_min_pos.x + chunk_size * chunk_x) + chunk_size - 1
			var max_y = (map_min_pos.y + chunk_size * chunk_y) + chunk_size - 1
			var chunk_data = {"chunk_x": chunk_x, "chunk_y": chunk_y, "min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y}

			# Create chunk node
			var chunk_node = Node2D.new()
			chunk_node.name = "Chunk (" + str(chunk_x) + "," + str(chunk_y) + ")"
			chunk_node.visible = false
			higher_chunks_node.add_child(chunk_node)
			chunk_node.set_owner(scene)
			
			# Create chunk with tilemaps and objects
			create_chunk(scene, chunk_data, higher_duplicate, chunk_node, true)


# Method generates a single chunk with all nodes
func create_chunk(scene, chunk_data, ground_duplicate_origin, chunk_node, disable_tilemap_collision):
	for child in ground_duplicate_origin.get_children():
		if child is TileMap:
			var empty_tilemap = true # To check if tilemap in chunk is empty or not
			var new_tilemap = TileMap.new()
			new_tilemap.name = child.name
			var dirtLvl0TileMap : TileMap = scene.find_node("dirt lvl0")
			new_tilemap.tile_set = dirtLvl0TileMap.tile_set
			new_tilemap.cell_quadrant_size = 1
			new_tilemap.cell_y_sort = false
			new_tilemap.cell_clip_uv = true
			new_tilemap.cell_size = Vector2(16,16)
			for cellPos in child.get_used_cells():
				if cellPos.x >= chunk_data["min_x"] and cellPos.x <= chunk_data["max_x"] and cellPos.y >= chunk_data["min_y"] and cellPos.y <= chunk_data["max_y"]:
					if child.get_cellv(cellPos) != -1:
						empty_tilemap = false
						new_tilemap.set_cell(cellPos.x, cellPos.y, child.get_cellv(cellPos))
			
			# Check if tilemap is from "higher" and disable collision
			if disable_tilemap_collision:
				new_tilemap.set_collision_layer_bit(0, false)
			
			# Check if tilemap contains tiles and if it does add tilemap to chunk
			if not empty_tilemap:
				chunk_node.add_child(new_tilemap)
				new_tilemap.set_owner(scene)
		
		elif child is Sprite:
			# Check if child is in this chunk
			var child_position
			if child.region_rect.size.x == 0:
				child_position = Vector2(child.position.x + int(round((child.texture.get_size().x / child.hframes) * child.scale.x - 1)), child.position.y * child.scale.y - 1)
			else:
				var pos_x = child.position.x + int(round(child.region_rect.size.x * child.scale.x - 1))
				var pos_y = child.position.y - 1
				child_position = Vector2(pos_x, pos_y)
			var chunk = get_chunk_from_position(child_position)
			if chunk.x == chunk_data["chunk_x"] and chunk.y == chunk_data["chunk_y"]:
				var sprite = Sprite.new()
				sprite.name = child.name
				sprite.texture = child.texture
				sprite.centered = child.centered
				sprite.offset = child.offset
				sprite.hframes = child.hframes
				sprite.vframes = child.vframes
				sprite.frame = child.frame
				sprite.region_enabled = child.region_enabled
				sprite.region_rect = child.region_rect
				sprite.position = child.position
				sprite.scale = child.scale
				
				# Add parent and child to chunk
				chunk_node.add_child(sprite)
				sprite.set_owner(scene)
				
			else:
				continue
		
		elif child is StaticBody2D:
			# Check if child is in this chunk
			var child_position = child.position + child.get_child(0).shape.extents * 2 - Vector2(1,1)
			var chunk = get_chunk_from_position(child_position)
			if chunk.x == chunk_data["chunk_x"] and chunk.y == chunk_data["chunk_y"]:
				var node = StaticBody2D.new()
				node.name = child.name
				node.position = child.position
				chunk_node.add_child(node)
				node.set_owner(scene)
			else:
				continue
		
		elif child is Area2D:
			# Check if child is in this chunk
			var child_position = child.position + child.get_child(0).shape.extents
			var chunk = get_chunk_from_position(child_position)
			if chunk.x == chunk_data["chunk_x"] and chunk.y == chunk_data["chunk_y"]:
				var node = Area2D.new()
				node.name = child.name
				node.position = child.position
				chunk_node.add_child(node)
				node.set_owner(scene)
			else:
				continue
		
		elif child is CollisionShape2D:
			var node = CollisionShape2D.new()
			node.position = child.position
			chunk_node.add_child(node)
			node.set_owner(scene)
			var shape = RectangleShape2D.new()
			shape.extents = child.shape.extents
			node.shape = shape
		
		elif child is CustomLight:
			# Check if child is in this chunk
			var child_position = Vector2.ZERO
			
			# Chunk position
			# If child is WINDOW
			if child.get_node_or_null("Sprite") == null:
				child_position = child.position + child.get_node("LightPosition").position
			
			# If child is NORMAL LIGHT
			else:
				child_position = Vector2(child.position.x + (child.get_node("Sprite").texture.get_size().x - 1) * child.scale.x, child.position.y)
			
			var chunk = get_chunk_from_position(child_position)
			if chunk.x == chunk_data["chunk_x"] and chunk.y == chunk_data["chunk_y"]:
				var custom_light = CUSTOM_LIGHT.instance()
				custom_light.name = child.name
				custom_light.position = child.position
				custom_light.radius = child.radius
				
				# Nodes
				# If child is NORMAL LIGHT
				if child.get_node_or_null("Sprite") != null:
					var sprite = custom_light.get_node_or_null("Sprite")
					sprite.texture = child.get_node("Sprite").texture
				# If child is WINDOW
				else:
					var sprite = custom_light.get_node("Sprite")
					custom_light.remove_child(sprite)
				
				# Set custom_light to node
				chunk_node.add_child(custom_light)
				custom_light.set_owner(scene)
				for child_in_light in custom_light.get_children():
					child_in_light.set_owner(scene)
			continue
		
		elif child is AnimationPlayer:
			# Remove parent from child
			child.get_parent().remove_child(child)
			
			# Add parent and child to chunk
			chunk_node.add_child(child)
			child.set_owner(scene)
		
		elif child is Position2D:
			var chunk = get_chunk_from_position(child.position)
			if chunk.x == chunk_data["chunk_x"] and chunk.y == chunk_data["chunk_y"]:
				# Remove parent from child
				child.get_parent().remove_child(child)
				
				# Add parent and child to chunk
				chunk_node.add_child(child)
				child.set_owner(scene)
			continue
		
		else:
			var node = Node2D.new()
			node.name = child.name
			chunk_node.add_child(node)
			node.set_owner(scene)
		
		# Take sub-nodes
		if child.get_child_count() > 0:
			create_chunk(scene, chunk_data, ground_duplicate_origin.get_node(child.name), chunk_node.get_node(child.name), disable_tilemap_collision)
			if chunk_node.get_node(child.name).get_child_count() == 0:
				chunk_node.remove_child(chunk_node.get_node(child.name))
	
	return chunk_node


# Method to return the chunk coords to the given position
func get_chunk_from_position(global_position):
	var chunk = Vector2.ZERO
	var new_position = Vector2.ZERO
	new_position.x = abs(map_min_global_pos.x) + global_position.x
	new_position.y = abs(map_min_global_pos.y) + global_position.y
	
	chunk.x = floor(new_position.x / CONSTANTS.chunk_size_pixel)
	chunk.y = floor(new_position.y / CONSTANTS.chunk_size_pixel)
	return chunk


# Method to cleanup the scene
func remove_tilemaps(node):
	for child in node.get_children():
		if child.get_child_count() > 0:
			remove_tilemaps(child)
		else:
			# Remove all tilemaps excluding navigation tilemaps
			if child is TileMap:
				child.get_parent().remove_child(child)


# Method to cleanup the scene
	# Remove all sub-nodes which are not longer required
func cleanup_node(node):
	# Erase nodes except chunks
	for child in node.get_children():
		if child.name != "Chunks":
			node.remove_child(child)
		else:
			continue


# Method to iterate over all nodes and sets specific properties
func collect_tilemaps(node):
	for child in node.get_children():
		if child.get_child_count() > 0:
			collect_tilemaps(child)
		else:
			if child is TileMap:
				# Get maximum map size in tiles
				var used_cells = child.get_used_cells()
				for cell_pos in used_cells:
					if cell_pos.x < map_min_pos.x:
						map_min_pos.x = cell_pos.x
						var local_position = child.map_to_world(map_min_pos)
						map_min_global_pos.x = local_position.x
					elif cell_pos.x > map_max_pos.x:
						map_max_pos.x = cell_pos.x
					
					if cell_pos.y < map_min_pos.y:
						map_min_pos.y = cell_pos.y
						var local_position = child.map_to_world(map_min_pos)
						map_min_global_pos.y = local_position.y
					elif cell_pos.y > map_max_pos.y:
						map_max_pos.y = cell_pos.y


# Method to iterate over all nodes and sets specific properties
func iterate_over_nodes(node):
	for child in node.get_children():
		if child.get_child_count() > 0:
			iterate_over_nodes(child)
		else:
			if child is TileMap:
				child.cell_quadrant_size = 1
				child.cell_y_sort = false
			
			elif child is CollisionPolygon2D and child.get_parent().get_parent().name == "mobSpawns":
				child.disabled = true
				child.get_parent().set_collision_layer_bit(0, false)
				child.get_parent().set_collision_mask_bit(0, false)
				child.get_parent().monitoring = false
				child.get_parent().monitorable = false
			
			elif child is CollisionShape2D and child.get_parent().get_parent().name == "playerSpawns":
				child.disabled = true
				child.get_parent().set_collision_layer_bit(0, false)
				child.get_parent().set_collision_mask_bit(0, false)
				child.get_parent().monitoring = false
				child.get_parent().monitorable = false
			
			elif child is CollisionShape2D and child.get_parent().get_parent().name == "changeScenes":
				child.get_parent().set_collision_mask_bit(0, false)
				child.get_parent().monitoring = true
				child.get_parent().monitorable = false
			
			elif child is CollisionShape2D and child.get_parent().get_parent().name == "stairs":
				child.get_parent().set_collision_mask_bit(0, false)
				child.get_parent().monitoring = true
				child.get_parent().monitorable = false


# Method to iterate over all nodes in "scene" and compresses all tilemaps to only one
func compress_tilemaps(node):
	for child in node.get_children():
		if child.get_child_count() > 0:
			compress_tilemaps(child)
		else:
			if child is TileMap:
				for cellPos in child.get_used_cells():
					compressed_tilemap.set_cell(cellPos.x, cellPos.y, child.get_cellv(cellPos))


# Method to iterate over all nodes in "ground" and removes all tiles under collisionshapes in tilemap to use map as navigation map -> ONLY NOT DYNAMIC COLLISIONSHAPES
func remove_collisionshapes_from_not_dynamic_objects_from_tilemap(tilemap : TileMap, node_with_collisionshapes):
	for child in node_with_collisionshapes.get_children():
		if child.get_child_count() > 0:
			remove_collisionshapes_from_not_dynamic_objects_from_tilemap(tilemap, child)
		else:
			if child is CollisionShape2D and child.get_parent() is StaticBody2D:
				if "treasure" in child.get_parent().name:
					continue
				
				var xExtentsFactor = 2
				var yExtentsFactor = 2
					
				for x in (child.shape.extents.x * xExtentsFactor):
					for y in (child.shape.extents.y * yExtentsFactor):
						tilemap.set_cell(int(floor((child.get_parent().position.x + x) / 16)), int(floor((child.get_parent().position.y + y) / 16)), -1)


# Method to iterate over all nodes in "ground" and removes all tiles under collisionshapes in tilemap to use map as navigation map
func remove_collisiontiles_from_tilemap(tilemap : TileMap):
	var tile_set : TileSet = tilemap.tile_set
	for cellPos in tilemap.get_used_cells():
		var cell = tilemap.get_cell(cellPos.x, cellPos.y)
		var shapes = tile_set.tile_get_shapes(cell)
		if shapes.size() > 0:
			for shape in shapes:
				# If shape on tile is collision then generate again
				if shape["shape"] is RectangleShape2D:
					tilemap.set_cell(cellPos.x, cellPos.y, -1)


# Loops through all cells within the map's bounds and
# adds all points to the mobs_astar_node, except the obstacles.
func astar_add_walkable_cells_for_mobs(astar_nodes_dics):
	for y in range(map_offset_in_tiles.y, map_offset_in_tiles.y + map_size_in_tiles.y + 1):
		for x in range(map_offset_in_tiles.x, map_offset_in_tiles.x + map_size_in_tiles.x + 1):
			var tile_coord = Vector2(x, y)
			
			# Check if tile_coord is no walkable tile / is outside of map (in map rectangle)
			if mobs_nav_tilemap.get_cell(tile_coord.x, tile_coord.y) == -1:
				continue
			
			# Make from one tile nine points
			for point_y in range(3): # 0, 1, 2
				for point_x in range(3): # 0, 1, 2
					var point = Vector2(point_x, point_y)
					
					var valid_point = true
					
					# Check CORNERS
					if (point.x == 0 or point.x == 2) \
					 and (point.y == 0 or point.y == 2):
						# Point is on CORNER - check if neighbor points are invalid
						# Check RIGHT-DOWN, LEFT-DOWN, LEFT-UP, RIGHT-UP
						point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
						var points_diagonal_relative = PoolVector2Array([
							point + Vector2(1,1), # RIGHT-DOWN
							point + Vector2(-1,1), # LEFT-DOWN
							point + Vector2(-1,-1), # LEFT-UP
							point + Vector2(1,-1), # RIGHT-UP
						])
						for point_relative in points_diagonal_relative:
							# Check if neighbor point is invalid
							var point_tile_coord_relative = mobs_nav_tilemap.world_to_map(point_coords_world(point_relative))
							if mobs_nav_tilemap.get_cell(point_tile_coord_relative.x, point_tile_coord_relative.y) == -1:
								valid_point = false
								break
					
					# Check EDGES
					elif (point.x == 1 and point.y == 0) \
					 or (point.x == 0 and point.y == 1) \
					 or (point.x == 2 and point.y == 1) \
					 or (point.x == 1 and point.y == 2):
						# Point is on EDGE - check if neighbor points are invalid
						
						# Check DOWN, UP
						if (point.x == 1 and point.y == 0) \
					 	 or (point.x == 1 and point.y == 2):
							point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
							# Take DOWN and UP point
							var points_vertical_relative = PoolVector2Array([
								point + Vector2.DOWN, # Vector2( 0, 1 )
								point + Vector2.UP, # Vector2( 0, -1 )
							])
							for point_relative in points_vertical_relative:
								# Check if neighbor point is invalid
								var point_tile_coord_relative = mobs_nav_tilemap.world_to_map(point_coords_world(point_relative))
								if mobs_nav_tilemap.get_cell(point_tile_coord_relative.x, point_tile_coord_relative.y) == -1:
									valid_point = false
									break
						
						# Check RIGHT, LEFT
						elif (point.x == 0 and point.y == 1) \
					 	 or (point.x == 2 and point.y == 1):
							point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
							# Take RIGHT and LEFT point
							var points_horizontal_relative = PoolVector2Array([
								point + Vector2.RIGHT, # Vector2( 1, 0 )
								point + Vector2.LEFT, # Vector2( -1, 0 )
							])
							for point_relative in points_horizontal_relative:
								# Check if neighbor point is invalid
								var point_tile_coord_relative = mobs_nav_tilemap.world_to_map(point_coords_world(point_relative))
								if mobs_nav_tilemap.get_cell(point_tile_coord_relative.x, point_tile_coord_relative.y) == -1:
									valid_point = false
									break
					
					# Check CENTER
					elif (point.x == 1 and point.y == 1):
						point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
						var point_tile_coord = mobs_nav_tilemap.world_to_map(point_coords_world(point))
						# Check if point is invalid
						if mobs_nav_tilemap.get_cell(point_tile_coord.x, point_tile_coord.y) == -1:
							valid_point = false
					
					# Add point if valid
					if valid_point:
						if not astar_nodes_dics["mobs"]["points"].has(point):
							# The AStar class references points with indices.
							# Using a function to calculate the index from a tile_coord's coordinates
							# ensures to always get the same index with the same input tile_coord
							var point_index = calculate_point_index(point)
							astar_nodes_dics["mobs"]["points"][point] = {
												"point_index" : point_index,
												"connections" : []
												}


# Loops through all cells within the map's bounds and
# adds all points to the mobs_astar_node, except the obstacles.
func astar_add_walkable_cells_for_bosses(astar_nodes_dics):
	for y in range(map_offset_in_tiles.y, map_offset_in_tiles.y + map_size_in_tiles.y + 1):
		for x in range(map_offset_in_tiles.x, map_offset_in_tiles.x + map_size_in_tiles.x + 1):
			var tile_coord = Vector2(x, y)
			
			# Check if tile_coord is no walkable tile / is outside of map (in map rectangle)
			if mobs_nav_tilemap.get_cell(tile_coord.x, tile_coord.y) == -1:
				continue
			
			else:
				var cell_is_invalid = false
				var mob_radius = 2
				for cell_x in range(-mob_radius, mob_radius + 1):
					for cell_y in range(-mob_radius, mob_radius + 1):
						var cell_id = mobs_nav_tilemap.get_cell(tile_coord.x + cell_x, tile_coord.y + cell_y)
						if cell_id == -1:
							cell_is_invalid = true
				
				if cell_is_invalid:
					continue
			
			# Make from one tile nine points
			for point_y in range(3): # 0, 1, 2
				for point_x in range(3): # 0, 1, 2
					var point = Vector2(point_x, point_y)
					
					var valid_point = true
					
					# Check CORNERS
					if (point.x == 0 or point.x == 2) \
					 and (point.y == 0 or point.y == 2):
						# Point is on CORNER - check if neighbor points are invalid
						# Check RIGHT-DOWN, LEFT-DOWN, LEFT-UP, RIGHT-UP
						point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
						var points_diagonal_relative = PoolVector2Array([
							point + Vector2(1,1), # RIGHT-DOWN
							point + Vector2(-1,1), # LEFT-DOWN
							point + Vector2(-1,-1), # LEFT-UP
							point + Vector2(1,-1), # RIGHT-UP
						])
						for point_relative in points_diagonal_relative:
							# Check if neighbor point is invalid
							var point_tile_coord_relative = mobs_nav_tilemap.world_to_map(point_coords_world(point_relative))
							if mobs_nav_tilemap.get_cell(point_tile_coord_relative.x, point_tile_coord_relative.y) == -1:
								valid_point = false
								break
					
					# Check EDGES
					elif (point.x == 1 and point.y == 0) \
					 or (point.x == 0 and point.y == 1) \
					 or (point.x == 2 and point.y == 1) \
					 or (point.x == 1 and point.y == 2):
						# Point is on EDGE - check if neighbor points are invalid
						
						# Check DOWN, UP
						if (point.x == 1 and point.y == 0) \
					 	 or (point.x == 1 and point.y == 2):
							point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
							# Take DOWN and UP point
							var points_vertical_relative = PoolVector2Array([
								point + Vector2.DOWN, # Vector2( 0, 1 )
								point + Vector2.UP, # Vector2( 0, -1 )
							])
							for point_relative in points_vertical_relative:
								# Check if neighbor point is invalid
								var point_tile_coord_relative = mobs_nav_tilemap.world_to_map(point_coords_world(point_relative))
								if mobs_nav_tilemap.get_cell(point_tile_coord_relative.x, point_tile_coord_relative.y) == -1:
									valid_point = false
									break
						
						# Check RIGHT, LEFT
						elif (point.x == 0 and point.y == 1) \
					 	 or (point.x == 2 and point.y == 1):
							point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
							# Take RIGHT and LEFT point
							var points_horizontal_relative = PoolVector2Array([
								point + Vector2.RIGHT, # Vector2( 1, 0 )
								point + Vector2.LEFT, # Vector2( -1, 0 )
							])
							for point_relative in points_horizontal_relative:
								# Check if neighbor point is invalid
								var point_tile_coord_relative = mobs_nav_tilemap.world_to_map(point_coords_world(point_relative))
								if mobs_nav_tilemap.get_cell(point_tile_coord_relative.x, point_tile_coord_relative.y) == -1:
									valid_point = false
									break
					
					# Check CENTER
					elif (point.x == 1 and point.y == 1):
						point = point + Vector2(2 * tile_coord.x, 2 * tile_coord.y) # Set point to real grid
						var point_tile_coord = mobs_nav_tilemap.world_to_map(point_coords_world(point))
						# Check if point is invalid
						if mobs_nav_tilemap.get_cell(point_tile_coord.x, point_tile_coord.y) == -1:
							valid_point = false
					
					# Add point if valid
					if valid_point:
						if not astar_nodes_dics["bosses"]["points"].has(point):
							# The AStar class references points with indices.
							# Using a function to calculate the index from a tile_coord's coordinates
							# ensures to always get the same index with the same input tile_coord
							var point_index = calculate_point_index(point)
							astar_nodes_dics["bosses"]["points"][point] = {
												"point_index" : point_index,
												"connections" : []
												}


# Loops through all cells within the map's bounds and
# adds all points to the ambient_mobs_astar_node, except the obstacles.
func astar_add_walkable_cells_for_ambient_mobs(astar_nodes_dics):
	for y in range(map_offset_in_tiles.y, map_offset_in_tiles.y + map_size_in_tiles.y + 1):
		for x in range(map_offset_in_tiles.x, map_offset_in_tiles.x + map_size_in_tiles.x + 1):
			var point = Vector2(x, y)
			
			# Check if point is no walkable tile / is outside of map (in map rectangle)
			if ambient_mobs_nav_tilemap.get_cell(point.x, point.y) == -1:
				continue
			
			# The AStar class references points with indices.
			# Using a function to calculate the index from a point's coordinates
			# ensures to always get the same index with the same input point
			var point_index = calculate_point_index(point)
			astar_nodes_dics["ambient_mobs"]["points"][point] = {
					"point_index" : point_index,
					"connections" : []
					}


# After added all points to the mobs_astar_node, connect them
func astar_connect_walkable_cells_for_mobs(astar_nodes_dics : Dictionary):
	for point in astar_nodes_dics["mobs"]["points"].keys():
		
		# For every cell in the map, we check the one to the top, right, 
		# left and bottom of it. If it's in the map and not an obstalce -> connect it
		var points_relative = PoolVector2Array([
			point + Vector2.RIGHT, # Vector2( 1, 0 )
			point + Vector2(1,1), # RIGHT-DOWN
			point + Vector2.DOWN, # Vector2( 0, 1 )
			point + Vector2(-1,1), # LEFT-DOWN
			point + Vector2.LEFT, # Vector2( -1, 0 )
			point + Vector2(-1,-1), # LEFT-UP
			point + Vector2.UP, # Vector2( 0, -1 )
			point + Vector2(1,-1), # RIGHT-UP
		])
		
		for point_relative in points_relative:
			var point_relative_index = calculate_point_index(point_relative)
			# Check point_relative
			if not astar_nodes_dics["mobs"]["points"].has(point_relative):
				continue
			
			# Connect points if everything is okay
			astar_nodes_dics["mobs"]["points"][point]["connections"].append(point_relative_index)


# After added all points to the mobs_astar_node, connect them
func astar_connect_walkable_cells_for_bosses(astar_nodes_dics : Dictionary):
	for point in astar_nodes_dics["bosses"]["points"].keys():
		
		# For every cell in the map, we check the one to the top, right, 
		# left and bottom of it. If it's in the map and not an obstalce -> connect it
		var points_relative = PoolVector2Array([
			point + Vector2.RIGHT, # Vector2( 1, 0 )
			point + Vector2(1,1), # RIGHT-DOWN
			point + Vector2.DOWN, # Vector2( 0, 1 )
			point + Vector2(-1,1), # LEFT-DOWN
			point + Vector2.LEFT, # Vector2( -1, 0 )
			point + Vector2(-1,-1), # LEFT-UP
			point + Vector2.UP, # Vector2( 0, -1 )
			point + Vector2(1,-1), # RIGHT-UP
		])
		
		for point_relative in points_relative:
			var point_relative_index = calculate_point_index(point_relative)
			# Check point_relative
			if not astar_nodes_dics["bosses"]["points"].has(point_relative):
				continue
			
			# Connect points if everything is okay
			astar_nodes_dics["bosses"]["points"][point]["connections"].append(point_relative_index)


# After added all points to the ambient_mobs_astar_node, connect them
func astar_connect_walkable_cells_for_ambient_mobs(astar_nodes_dics):
	for point in astar_nodes_dics["ambient_mobs"]["points"].keys():
		
		# For every cell in the map, we check the one to the top, right, 
		# left and bottom of it. If it's in the map and not an obstalce -> connect it
		var points_relative = PoolVector2Array([
			point + Vector2.RIGHT, # Vector2( 1, 0 )
			point + Vector2(1,1), # RIGHT-DOWN
			point + Vector2.DOWN, # Vector2( 0, 1 )
			point + Vector2(-1,1), # LEFT-DOWN
			point + Vector2.LEFT, # Vector2( -1, 0 )
			point + Vector2(-1,-1), # LEFT-UP
			point + Vector2.UP, # Vector2( 0, -1 )
			point + Vector2(1,-1), # RIGHT-UP
		])
		
		for point_relative in points_relative:
			var point_relative_index = calculate_point_index(point_relative)
			# Check point_relative
			if not astar_nodes_dics["ambient_mobs"]["points"].has(point_relative):
				continue
			
			# Connect points if everything is okay
			astar_nodes_dics["ambient_mobs"]["points"][point]["connections"].append(point_relative_index)


# Method to generate tile_coord to global_position
func point_coords_world(tile_coords : Vector2):
	var global_position = Vector2.ZERO
	global_position.x = tile_coords.x * (float(CONSTANTS.TILE_SIZE) / (CONSTANTS.POINTS_HORIZONTAL_PER_TILE - 1))
	global_position.y = tile_coords.y * (float(CONSTANTS.TILE_SIZE) / (CONSTANTS.POINTS_VERTICAL_PER_TILE - 1))
	
	return global_position


# Method calculates the index of the point in astar_nodes - INPUT: Tilecoords like (-272, -144) or (128, 64)
func calculate_point_index(point):
	# Points are from (-272, -144) to (128, 64)
	# Make them to (0, 0) to (400, 208)
	point -= map_offset_in_tiles * 2
	
	return point.x + map_size_in_tiles.x * 2 * point.y
