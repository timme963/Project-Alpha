extends CanvasLayer

signal player_interact

var input
var show_map = false
var has_map = false
var is_dialog = false


func _ready():
	pass


func in_world(value):
	if value:
		get_node("ControlNotes").in_world(value)
		get_node("PlayerUI").visible = value
	else:
		get_node("ControlNotes").in_world(value)
		get_node("PlayerUI").visible = value


# pause and resume the player input
func player_input(new_value):
	input = new_value


func _input(event):
	Utils.get_control_notes().update()
	# only can do interactions while mot scene changeing
	if input:
		if event.is_action_pressed("e"):
			
			if (Utils.get_current_player().get_player_can_interact() and 
			not Utils.get_current_player().is_attacking and not Utils.get_current_player().is_player_dying()):
				emit_signal("player_interact")
				
			# Remove the Loot Panel
			elif Utils.get_loot_panel() != null:
				# Call close Method in Loot Panel
				Utils.get_loot_panel()._on_Close_pressed()
				
			# Remove the trade inventory
			elif Utils.get_trade_inventory() != null:
				Utils.get_trade_inventory().queue_free()
				Utils.get_current_player().set_player_can_interact(true)
				Utils.get_current_player().set_movement(true)
				Utils.get_current_player().set_movment_animation(true)
				# Reset npc interaction state
				for npc in Utils.get_scene_manager().get_current_scene().find_node("npclayer").get_children():
					npc.set_interacted(false)
				Utils.save_game()
				Utils.get_main().get_node("LoadingScreen/SaveScreen").play("Saved")
				MerchantData.save_merchant_inventory()
		
		# Open game menu with "esc"
		elif (event.is_action_pressed("esc") and Utils.get_current_player().get_movement() and 
		not Utils.get_current_player().hurting and not Utils.get_current_player().is_player_dying() and 
		Utils.get_game_menu() == null):
			Utils.get_current_player().set_movement(false)
			Utils.get_current_player().set_movment_animation(false)
			Utils.get_current_player().set_player_can_interact(false)
			Utils.get_ui().add_child(load(Constants.GAME_MENU_PATH).instance())
		# Close game menu with "esc" when game menu is open
		elif event.is_action_pressed("esc") and !Utils.get_current_player().get_movement() and Utils.get_game_menu() != null:
			Utils.get_current_player().set_movement(true)
			Utils.get_current_player().set_movment_animation(true)
			Utils.get_current_player().set_player_can_interact(true)
			Utils.get_game_menu().queue_free()
		
		# Open character inventory with "i"
		elif (event.is_action_pressed("character_inventory") and Utils.get_current_player().get_movement() and 
		not Utils.get_current_player().collecting and 
		not Utils.get_current_player().is_player_dying() and Utils.get_character_interface() == null):
			Utils.get_current_player().set_movement(false)
			Utils.get_current_player().set_movment_animation(false)
			Utils.get_current_player().set_player_can_interact(false)
			Utils.get_ui().add_child(load(Constants.CHARACTER_INTERFACE_PATH).instance())
		# Close character inventory with "i"
		elif (event.is_action_pressed("character_inventory") and not Utils.get_current_player().get_movement() 
		and Utils.get_character_interface() != null):
			Utils.get_current_player().set_movement(true)
			Utils.get_current_player().set_movment_animation(true)
			Utils.get_current_player().set_player_can_interact(true)
			PlayerData.inv_data["Weapon"] = PlayerData.equipment_data["Weapon"]
			PlayerData.inv_data["Light"] = PlayerData.equipment_data["Light"]
			PlayerData.inv_data["Hotbar"] = PlayerData.equipment_data["Hotbar"]
			Utils.save_game()
			Utils.get_main().get_node("LoadingScreen/SaveScreen").play("Saved")
			Utils.get_character_interface().queue_free()
		
		# Use Item from Hotbar
		elif event.is_action_pressed("hotbar") and not Utils.get_current_player().is_player_dying():
			Utils.get_hotbar().use_item()
			
		# Control Notes
		elif event.is_action_pressed("control_notes") and not is_dialog:
			Utils.get_control_notes().show_hide_control_notes()
			
		# open map
		elif (Utils.get_scene_manager().get_current_scene_type() != Constants.SceneType.DUNGEON and not is_dialog):
			if event.is_action_pressed("map") and has_map and !show_map:
				show_map = true
				Utils.get_current_player().get_data().show_map = show_map
				Utils.get_minimap().update_minimap()
		
			# close map
			elif event.is_action_pressed("map") and has_map and show_map:
				show_map = false
				Utils.get_current_player().get_data().show_map = show_map
				Utils.get_minimap().update_minimap()

