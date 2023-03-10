extends Node

# Variables
var mobspawner_thread = Thread.new()
var can_spawn_mobs = false
var mob_spawner_timer = Timer.new()
var mob_spawn_interval = null # float
var should_spawn_mobs = false
var spawning_areas = null
var with_ambient_mobs : bool = false
var mob_list : Array
var mob_list_mutex = Mutex.new()
var current_ambient_mobs : int
var max_ambient_mobs : int
var is_time_sensitiv : bool = false
var mobs_to_despawn : Array
var mobs_to_despawn_mutex = Mutex.new()
var world
var change_to_sunrise = false
var change_to_night = false


# Called when the node enters the scene tree for the first time.
func _ready():
	print("MOB_SPAWNER_SERVICE: Start")
	
	# Add mob_spawner_timer
	add_child(mob_spawner_timer)
	mob_spawner_timer.connect("timeout", self, "spawn_despawn_mobs")


# Method to init all important variables
# Called from another thread
func init(init_world, new_spawning_areas, new_with_ambient_mobs, new_max_ambient_mobs, new_is_time_sensitiv, new_mob_respawn_timer : float = Constants.MOB_RESPAWN_TIMER):
	print("MOB_SPAWNER_SERVICE: Init")
	# Check if thread is active wait to stop
	if mobspawner_thread.is_active():
		clean_thread()
	
	# Init variables
	world = init_world
	spawning_areas = new_spawning_areas
	with_ambient_mobs = new_with_ambient_mobs
	max_ambient_mobs = new_max_ambient_mobs
	is_time_sensitiv = new_is_time_sensitiv
	mob_spawn_interval = new_mob_respawn_timer
	# Activate time specific mobs depending on scene_tpye
	if is_time_sensitiv:
		# Connect signals
		var _error1 = DayNightCycle.connect("change_to_sunrise", self, "on_change_to_sunrise")
		var _error2 = DayNightCycle.connect("change_to_night", self, "on_change_to_night")
	
	# Start mobspawner thread
	mobspawner_thread.start(self, "handle_mob_spawns")
	can_spawn_mobs = true
	should_spawn_mobs = false


# Method to stop the mobspawner to change map
# Called from another thread
func stop():
	# Reset variables
	can_spawn_mobs = null
	mob_spawner_timer = null
	mob_spawn_interval = null
	should_spawn_mobs = null
	change_to_sunrise = null
	change_to_night = null
	
	print("MOB_SPAWNER_SERVICE: Stopped")


# Method to cleanup the mobspawner
# Called from another thread
func cleanup():
	# Check if thread is active wait to stop
	can_spawn_mobs = false
	should_spawn_mobs = false
	if mobspawner_thread.is_active():
		clean_thread()
	
	# Reset variables
	spawning_areas = null
	with_ambient_mobs = false
	current_ambient_mobs = 0
	max_ambient_mobs = 0
	mobs_to_despawn.clear()
	# -> Reset timer
	mob_spawner_timer.stop()
	# -> Disconnect signals
	if is_time_sensitiv:
		if DayNightCycle.is_connected("change_to_sunrise", self, "on_change_to_sunrise"):
			DayNightCycle.disconnect("change_to_sunrise", self, "on_change_to_sunrise")
		if DayNightCycle.is_connected("change_to_night", self, "on_change_to_night"):
			DayNightCycle.disconnect("change_to_night", self, "on_change_to_night")
	# -> Clean mobs
	for mob in mob_list:
		if Utils.is_node_valid(mob):
			mob.call_deferred("queue_free")
	mob_list.clear()
	world = null
	change_to_sunrise = false
	change_to_night = false
	
	print("MOB_SPAWNER_SERVICE: Cleaned")


# Method to activate spawn mobs
# Called from another thread
func spawn_mobs():
	if can_spawn_mobs:
		should_spawn_mobs = true
		# Activate mob_spawner_timer
		mob_spawner_timer.set_wait_time(mob_spawn_interval)
		mob_spawner_timer.start()


# Method to load active chunks in background
func handle_mob_spawns():
	while can_spawn_mobs:
		
		# Handle time changes
		# To sunrise
		if change_to_sunrise:
			change_to_sunrise = false
			# Spawn specific day mobs and remove specific night mobs
			# Remove mobs
			mob_list_mutex.lock()
			mobs_to_despawn_mutex.lock()
			for mob in mob_list:
				if Utils.is_node_valid(mob):
					if mob.spawn_time == Constants.SpawnTime.ONLY_NIGHT and mobs_to_despawn.find(mob) == -1:
						mobs_to_despawn.append(mob)
			mobs_to_despawn_mutex.unlock()
			mob_list_mutex.unlock()
			# Despawn and spawn mobs
			should_spawn_mobs = true
		
		# To night
		if change_to_night:
			change_to_night = false
			# Spawn specific night mobs and remove specific day mobs
			# Remove mobs
			mob_list_mutex.lock()
			mobs_to_despawn_mutex.lock()
			for mob in mob_list:
				if Utils.is_node_valid(mob):
					if mob.spawn_time == Constants.SpawnTime.ONLY_DAY and mobs_to_despawn.find(mob) == -1:
						mobs_to_despawn.append(mob)
			mobs_to_despawn_mutex.unlock()
			mob_list_mutex.unlock()
			# Despawn and spawn mobs
			should_spawn_mobs = true
		
		
		# Handle mob spawning
		if should_spawn_mobs == true:
			should_spawn_mobs = false
			
			# Despawn mobs if necessary
			mobs_to_despawn_mutex.lock()
			if mobs_to_despawn.size() > 0:
				despawn_mobs()
			mobs_to_despawn_mutex.unlock()
			
			# Spawn area mobs
			spawn_area_mobs()
			
			if with_ambient_mobs:
				# Spawn ambient mobs
				spawn_ambient_mobs()


# Method is called when thread finished
func clean_thread():
	# Wait for thread to finish
	mobspawner_thread.wait_to_finish()


# Method to despawn mobs if mobs_to_despawn > 0
func despawn_mobs():
	var removed_mobs = []
	for mob in mobs_to_despawn:
		if Utils.is_node_valid(mob):
			# Remove mob if it is not in camera screen
			if not Utils.is_position_in_camera_screen(mob.global_position):
				if mob.is_in_group("Ambient Mob"):
					current_ambient_mobs -= 1
				elif mob.is_in_group("Enemy"):
					spawning_areas[mob.spawnArea]["current_mobs_count"] -= 1
				
				removed_mobs.append(mobs_to_despawn.find(mob))
				
				if Utils.is_node_valid(mob):
					mob.call_deferred("queue_free")
				
				mob_list_mutex.lock()
				mob_list.remove(mob_list.find(mob))
				mob_list_mutex.unlock()
	
	var i = 0
	for removed_mob in removed_mobs:
		mobs_to_despawn.remove(removed_mob - i)
		i += 1
	removed_mobs.clear()


# Method to spawn mobs
func spawn_area_mobs():
	for current_spawn_area in spawning_areas.keys():
		# Spawn area informations
		var biome_mobs_count = spawning_areas[current_spawn_area]["biome_mobs_count"]
		var max_mobs = spawning_areas[current_spawn_area]["max_mobs"]
		var biome_mobs = spawning_areas[current_spawn_area]["biome_mobs"]
		
		# Get count of mobs to spawn
		var spawn_mobs_counter = max_mobs - spawning_areas[current_spawn_area]["current_mobs_count"]
		
		# Spawn only if needed
		if spawn_mobs_counter > 0:
			var mobs_to_spawn : Array = []
			mobs_to_spawn = Utils.get_spawn_mobs_list(biome_mobs_count, spawn_mobs_counter)
			# Iterate over diffent mobs classes
			for mob in range(biome_mobs.size()):
				# Check if mob should be spawned
				if mob in mobs_to_spawn:
					# Load and spawn mobs
					var mobScene : PackedScene = Constants.PreloadedMobScenes[biome_mobs[mob]]
					
					if mobScene != null:
						# Spawn the mob as often as it is in the list
						for mob_id in mobs_to_spawn:
							if mob == mob_id:
								world.call_deferred("spawn_mob", mobScene, current_spawn_area)
								spawning_areas[current_spawn_area]["current_mobs_count"] += 1
					
					else:
						printerr("ERROR: \""+ biome_mobs[mob] + "\" scene can't be loaded!")


# Method to spawn ambient mobs
func spawn_ambient_mobs():
	# Spawn only if needed
	if current_ambient_mobs < max_ambient_mobs:
		# Spawn ambient mobs
		# Check time
		if DayNightCycle.is_night:
			# NIGHT
			# Spawn moths
			var mobScene : Resource = Constants.PreloadedMobScenes["Moth"]
			if mobScene != null:
				while current_ambient_mobs < max_ambient_mobs:
					world.call_deferred("spawn_ambient_mob", mobScene, Constants.SpawnTime.ONLY_NIGHT)
					current_ambient_mobs += 1
			
			else:
				printerr("ERROR: \"Moth\" scene can't be loaded!")
		
		else:
			# DAY
			# Spawn butterflies
			var mobScene : Resource = Constants.PreloadedMobScenes["Butterfly"]
			if mobScene != null:
				while current_ambient_mobs < max_ambient_mobs:
					world.call_deferred("spawn_ambient_mob", mobScene, Constants.SpawnTime.ONLY_DAY)
					current_ambient_mobs += 1
			
			else:
				printerr("ERROR: \"Butterfly\" scene can't be loaded!")


# Method to despawn/remove mob - NOT FOR AMBIENT MOBS - called from mob
# Called from another thread but with call_deferred so this method is executed in this thread
func despawn_mob(mob):
	if Utils.is_node_valid(mob):
		# Remove from variables
		mob_list_mutex.lock()
		if mob_list.find(mob) != -1:
			mob_list.remove(mob_list.find(mob))
		mob_list_mutex.unlock()
		
		mobs_to_despawn_mutex.lock()
		if mobs_to_despawn.find(mob) != -1:
			mobs_to_despawn.remove(mobs_to_despawn.find(mob))
		mobs_to_despawn_mutex.unlock()
		
		# Remove from nodes
		spawning_areas[mob.spawnArea]["current_mobs_count"] -= 1
		mob.call_deferred("queue_free")
		print("MOB_SPAWNER_SERVICE: Mob \"" + mob.name + "\" removed")


# Method is called from mob_spawner_timer -> new mobs should be spawned or  mobs should be removed
func spawn_despawn_mobs():
	if can_spawn_mobs:
		should_spawn_mobs = true
		mob_spawner_timer.set_wait_time(mob_spawn_interval)
		mob_spawner_timer.start()


# Method to recognize sunrise
func on_change_to_sunrise():
	change_to_sunrise = true


# Method to recognize night
func on_change_to_night():
	change_to_night = true


# Method to enable or disable mob respawning
# Called from another thread
func disable_mob_respawning(disable):
	can_spawn_mobs = !disable
	
	# Disble mob respawn
	if disable:
		can_spawn_mobs = false
		mob_spawner_timer.stop()
	# Enable mob respawn
	else:
		can_spawn_mobs = true
		mob_spawner_timer.set_wait_time(mob_spawn_interval)
		mob_spawner_timer.start()


# Method is called from world after mob is instanced and added to world -> to handle mob spawning/despawning
# Called from another thread but with call_deferred so this method is executed in this thread
func new_mob_spawned(mob_instance):
	mob_list_mutex.lock()
	mob_list.append(mob_instance)
	mob_list_mutex.unlock()
