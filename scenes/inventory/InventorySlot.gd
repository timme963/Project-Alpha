extends TextureRect

var tool_tip = Constants.PreloadedScenes.TooltipScene
var split_popup = Constants.PreloadedScenes.SplitPopupScene
var inv_slot = Constants.PreloadedScenes.TradeInvSlotScene

onready var time_label = get_node("TextureProgress/Time")
onready var cooldown_texture = get_node("TextureProgress")
var disabled = false
onready var timer = get_node("../Timer")
var swap = false
var stack = false
var type



func _ready():
	time_label.hide()
	timer.wait_time = Constants.HEALTH_COOLDOWN
	cooldown_texture.value = 0
	set_process(false)
	timer.set_one_shot(true)


# Update cooldown label
func _process(_delta):
	time_label.text = "%2.1f" % timer.time_left
	if type == "Stamina":
		cooldown_texture.value = int((timer.time_left / Constants.STAMINA_POTION_COOLDOWN) * 100)
	else:
		cooldown_texture.value = int((timer.time_left / Constants.HEALTH_COOLDOWN) * 100)


func _on_Timer_timeout():
	set_process(false)
	cooldown_texture.value = 0
	disabled = false
	time_label.hide()


# Get information about drag item
func get_drag_data(_pos):
	var slot = get_parent().get_name()
	if PlayerData.inv_data[slot]["Item"] != null:
		Utils.set_and_play_sound(Constants.PreloadedSounds.Select)
		var data = {}
		data["origin_node"] = self
		data["origin_panel"] = "Inventory"
		data["origin_item_id"] = PlayerData.inv_data[slot]["Item"]
		data["origin_slot"] = GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]
		data["origin_texture"] = get_child(0).texture
		data["origin_frame"] = get_child(0).frame
		data["origin_stackable"] = GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]["Stackable"]
		data["origin_stack"] = PlayerData.inv_data[slot]["Stack"]
		
		# Texture wich will drag
		var drag_texture = Sprite.new()
		if GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]["Texture"] == "item_icons_1":
			drag_texture.set_scale(Vector2(1.5,1.5))
			drag_texture.set_hframes(16)
			drag_texture.set_vframes(27)
			drag_texture.texture = get_child(0).texture
			drag_texture.frame = get_child(0).frame
		else:
			drag_texture.set_scale(Vector2(2.5,2.5))
			drag_texture.set_hframes(13)
			drag_texture.set_vframes(15)
			drag_texture.texture = get_child(0).texture
			drag_texture.frame = get_child(0).frame
		
		# Pos on mouse while drag
		var control = Control.new()
		control.add_child(drag_texture)
		drag_texture.position = -0.5 * drag_texture.scale
		set_drag_preview(control)
		
		return data

# Check if we can drop an item to this slot
func can_drop_data(_pos, data):
	var target_slot = get_parent().get_name()
	var player_gold = int(Utils.get_current_player().get_gold())
	# Move item
	if PlayerData.inv_data[target_slot]["Item"] == null:
		data["target_item_id"] = null
		data["target_texture"] = null
		data["target_stack"] = null
		data["target_frame"] = null
		if data["origin_panel"] == "TradeInventory":
			if int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) * int(data["origin_stack"]) <= player_gold:
				return true
			else:
				if int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) <= player_gold:
					return true
				else:
					return false
		else:
			return true
	# Swap item
	else:
		if data["origin_panel"] != "CharacterInterface" or check_category(data):
			data["target_item_id"] = PlayerData.inv_data[target_slot]["Item"]
			data["target_texture"] = get_child(0).texture
			data["target_frame"] = get_child(0).frame
			data["target_stack"] = PlayerData.inv_data[target_slot]["Stack"]
			# not swaping with 0 stack
			if data["target_stack"] == 0:
				return false
			elif data["origin_stack"] == 0 and !data["origin_stackable"]:
				return false
			elif (data["target_item_id"] != null and data["target_item_id"] != data["origin_item_id"]) and (Input.is_action_pressed("secondary") or data["origin_stack"] == 0):
				return false
			else:
				# check if buying
				if data["origin_panel"] == "TradeInventory":
					
					var resell_price = int(ceil(int(GameData.item_data[str(data["target_item_id"])]["Worth"]) * Constants.RESELL_FACTOR))
					
					if data["target_item_id"] == data["origin_item_id"] and data["origin_stackable"]:
						if int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) * int(
							data["origin_stack"]) <= player_gold:
							return true
						else:
							if int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) <= player_gold:
								return true
							else:
								return false
					elif int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) * int(
						data["origin_stack"]) <= player_gold + resell_price * int(data["target_stack"]):
						return true
					else:
						return false
				else:
					return true
		else:
			return false


# Check for same category
func check_category(data):
	if (GameData.item_data[str(PlayerData.inv_data[get_parent().get_name()]["Item"])]["Category"] in ["Potion", "Food"] and 
	GameData.item_data[str(data["origin_item_id"])]["Category"] in ["Potion", "Food"]):
		return true
	elif (GameData.item_data[str(PlayerData.inv_data[get_parent().get_name()]["Item"])]["Category"] == 
	GameData.item_data[str(data["origin_item_id"])]["Category"]):
		return true
	else:
		return false
	

func drop_data(_pos, data):
	var target_slot = get_parent().get_name()
	var origin_slot = data["origin_node"].get_parent().get_name()
	var player_gold = int(Utils.get_current_player().get_gold())
	var split = 0
	if data["origin_node"] == self:
		pass
	else:
		# splitting
		if Input.is_action_pressed("secondary") and data["origin_stack"] > 1 or data["origin_stack"] == 0:
			if data["origin_stackable"]:
				var split_popup_instance = split_popup.instance()
				split_popup_instance.rect_position = get_parent().get_global_transform_with_canvas().origin + Vector2(0,100)
				split_popup_instance.data = data
				add_child(split_popup_instance)
				get_node("ItemSplitPopup").show()
			else:
				SplitStack(1,data)
		else:
			# paying
			if data["origin_panel"] == "TradeInventory":
				if data["target_stack"] == Constants.MAX_STACK_SIZE:
					pass
				# swap
				elif data["target_item_id"] != null and (!data["origin_stackable"] or data["target_item_id"] != data["origin_item_id"]):
					Utils.get_trade_inventory().get_sound_player().stop()
					Utils.get_trade_inventory().get_sound_player().stream = Constants.PreloadedSounds.Collect
					Utils.get_trade_inventory().get_sound_player().play(0.03)
					
					var resell_price = int(ceil(int(GameData.item_data[str(data["target_item_id"])]["Worth"])) * Constants.RESELL_FACTOR)
					
					Utils.get_current_player().set_gold(player_gold - ((int(GameData.item_data[
						str(data["origin_item_id"])]["Worth"])) * int(data["origin_stack"])) + resell_price * int(data["target_stack"]))
				# buy
				else:
					Utils.get_trade_inventory().get_sound_player().stop()
					Utils.get_trade_inventory().get_sound_player().stream = Constants.PreloadedSounds.Collect
					Utils.get_trade_inventory().get_sound_player().play(0.03)
					if (int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) * int(data["origin_stack"]) > player_gold):
						split = int(player_gold/(int(GameData.item_data[str(data["origin_item_id"])]["Worth"])))
						Utils.get_current_player().set_gold(player_gold - (int(GameData.item_data[str(data["origin_item_id"])]["Worth"])) * split)
					else:
						Utils.get_current_player().set_gold(player_gold - (int(GameData.item_data[str(data["origin_item_id"])]["Worth"])) * int(data["origin_stack"]))
				Utils.get_trade_inventory().find_node("Inventory").get_child(0).find_node("Gold").set_text(
					"Gold: " + str(Utils.get_current_player().get_gold()))
			# Update the data of the origin
			# stacking
			if (data["target_item_id"] == data["origin_item_id"] and data["origin_stackable"] and 
			data["origin_panel"] == "Inventory" and data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE):
				Utils.set_and_play_sound(Constants.PreloadedSounds.Click)
				if data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE:
					PlayerData.inv_data[origin_slot]["Item"] = null
					PlayerData.inv_data[origin_slot]["Stack"] = null
				else:
					PlayerData.inv_data[origin_slot]["Stack"] = (PlayerData.inv_data[origin_slot]["Stack"] - 
					(Constants.MAX_STACK_SIZE - data["target_stack"]))
			elif (data["target_item_id"] == data["origin_item_id"] and data["origin_stackable"] and 
			data["origin_panel"] == "TradeInventory" and data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE):
				Utils.set_and_play_sound(Constants.PreloadedSounds.Click)
				if split != 0:
					MerchantData.inv_data[origin_slot]["Stack"] = data["origin_stack"] - split
				elif data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE:
					MerchantData.inv_data[origin_slot]["Item"] = null
					MerchantData.inv_data[origin_slot]["Stack"] = null
					MerchantData.inv_data[target_slot]["Time"] = null
				else:
					MerchantData.inv_data[origin_slot]["Stack"] = (MerchantData.inv_data[origin_slot]["Stack"] - 
					(Constants.MAX_STACK_SIZE - data["target_stack"]))
					MerchantData.inv_data[origin_slot]["Time"] = DayNightCycle.get_passed_days_since_start() * DayNightCycle.COMPLETE_DAY_TIME + DayNightCycle.get_current_time()
				check_slots()
			# stacking for hotbar
			elif (data["target_item_id"] == data["origin_item_id"] and data["origin_stackable"] and 
			data["origin_panel"] == "CharacterInterface" and data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE):
				Utils.set_and_play_sound(Constants.PreloadedSounds.Click)
				if data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE:
					PlayerData.equipment_data[origin_slot]["Item"] = null
					PlayerData.equipment_data[origin_slot]["Stack"] = null
				else:
					PlayerData.equipment_data[origin_slot]["Stack"] = (PlayerData.equipment_dataa[origin_slot]["Stack"] - 
					(Constants.MAX_STACK_SIZE - data["target_stack"]))
				Utils.get_hotbar().load_hotbar()
			# swaping
			# swap with item or null
			elif data["origin_panel"] == "Inventory":
				Utils.set_and_play_sound(Constants.PreloadedSounds.Switch)
				PlayerData.inv_data[origin_slot]["Item"] = data["target_item_id"]
				PlayerData.inv_data[origin_slot]["Stack"] = data["target_stack"]
			elif data["origin_panel"] == "TradeInventory":
				Utils.set_and_play_sound(Constants.PreloadedSounds.Switch)
				if split != 0:
					MerchantData.inv_data[origin_slot]["Stack"] = data["origin_stack"] - split
					MerchantData.inv_data[origin_slot]["Time"] = DayNightCycle.get_passed_days_since_start() * DayNightCycle.COMPLETE_DAY_TIME + DayNightCycle.get_current_time()
				else:
					MerchantData.inv_data[origin_slot]["Item"] = data["target_item_id"]
					MerchantData.inv_data[origin_slot]["Stack"] = data["target_stack"]
					if data["target_item_id"] != null:
						MerchantData.inv_data[origin_slot]["Time"] = DayNightCycle.get_passed_days_since_start() * DayNightCycle.COMPLETE_DAY_TIME + DayNightCycle.get_current_time()
					else:
						MerchantData.inv_data[origin_slot]["Time"] = null
				check_slots()
			elif data["origin_panel"] == "Delete":
				if PlayerData.inv_data[target_slot]["Item"] != null:
					Utils.set_and_play_sound(Constants.PreloadedSounds.Delete)
				else:
					Utils.set_and_play_sound(Constants.PreloadedSounds.Switch)
				data["origin_node"].item = PlayerData.inv_data[target_slot]["Item"]
				data["origin_node"].stack = PlayerData.inv_data[target_slot]["Stack"]
			else:
				# change equipment
				if data["target_item_id"] != null:
					Utils.set_and_play_sound(Constants.PreloadedSounds.Equip)
				else:
					Utils.set_and_play_sound(Constants.PreloadedSounds.Switch)
				PlayerData.equipment_data[origin_slot]["Item"] = data["target_item_id"]
				PlayerData.equipment_data[origin_slot]["Stack"] = data["target_stack"]
				# Weapon
				if GameData.item_data[str(data["origin_item_id"])]["Category"] == "Weapon":
					if PlayerData.equipment_data[origin_slot]["Item"] != null:
						var item_id = PlayerData.equipment_data[origin_slot]["Item"]
						var attack_value = GameData.item_data[str(PlayerData.equipment_data[origin_slot]["Item"])]["Attack"]
						var attack_speed = GameData.item_data[str(PlayerData.equipment_data[origin_slot]["Item"])]["Attack-Speed"]
						var knockback_value = GameData.item_data[str(PlayerData.equipment_data[origin_slot]["Item"])]["Knockback"]
						
						Utils.get_character_interface().find_node("Damage").set_text(
							tr("ATTACK") + ": " + str(attack_value))
						Utils.get_character_interface().find_node("Attack-Speed").set_text(
							tr("ATTACK-SPEED") + ": " + str(attack_speed))
						Utils.get_character_interface().find_node("Knockback").set_text(
							tr("KNOCKBACK") + ": " + str(knockback_value))
						
						Utils.get_current_player().set_weapon(item_id, attack_value, attack_speed, knockback_value)
					
					else:
						Utils.get_character_interface().find_node("Damage").set_text(
							tr("ATTACK") + ": " + "0")
						Utils.get_character_interface().find_node("Attack-Speed").set_text(
							tr("ATTACK-SPEED") + ": " + "0")
						Utils.get_character_interface().find_node("Knockback").set_text(
							tr("KNOCKBACK") + ": " + "0")

						Utils.get_current_player().set_weapon(null, 0, 0, 0)
				# Light
				elif GameData.item_data[str(data["origin_item_id"])]["Category"] == "Light":
					if PlayerData.equipment_data[origin_slot]["Item"] != null:
						var light_value = GameData.item_data[str(PlayerData.equipment_data[origin_slot]["Item"])]["Radius"]
						Utils.get_character_interface().find_node("LightRadius").set_text(
							tr("LIGHT") + ": " + str(light_value))
						Utils.get_current_player().set_light(light_value)
					else:
						Utils.get_character_interface().find_node("LightRadius").set_text(
							tr("LIGHT") + ": " + "0")
						Utils.get_current_player().set_light(0)
				# Hotbar
				else:
					Utils.get_hotbar().load_hotbar()

			# Update the texture and label of the origin
			# stacking
			if data["target_item_id"] == data["origin_item_id"] and data["origin_stackable"] and split == 0 and data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE:
				if data["origin_panel"] == "CharacterInterface" or data["origin_panel"] == "Delete":
					if data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE:
						data["origin_node"].get_child(0).texture = null
						data["origin_node"].get_node("TextureRect/Stack").set_text("")
						stack = true
					else:
						data["origin_node"].get_node("TextureRect/Stack").set_text(str(data["origin_stack"] - 
						(Constants.MAX_STACK_SIZE - data["target_stack"])))
				else:
					if data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE:
						data["origin_node"].get_child(0).texture = null
						data["origin_node"].get_node("../TextureRect/Stack").set_text("")
						stack = true
					else:
						data["origin_node"].get_node("../TextureRect/Stack").set_text(str(data["origin_stack"] - 
						(Constants.MAX_STACK_SIZE - data["target_stack"])))
				
			# swap
			elif data["origin_panel"] == "TradeInventory" and data["target_item_id"] == null and split == 0:
				data["origin_node"].get_child(0).texture = null
				data["origin_node"].get_node("../TextureRect/Stack").set_text("")
			elif data["origin_panel"] == "TradeInventory" and data["target_item_id"] == null and split != 0:
				data["origin_node"].get_node("../TextureRect/Stack").set_text(str(int(data["origin_stack"] - split)))
				verify_origin_texture(data)
			else:
				data["origin_node"].get_child(0).texture = data["target_texture"]
				verify_origin_texture(data)
				if data["target_frame"] != null:
					data["origin_node"].get_child(0).frame = data["target_frame"]
				if data["origin_panel"] == "Delete":
					if data["target_stack"] != null:
						data["origin_node"].get_node("TextureRect/Stack").set_text(str(data["target_stack"]))
					else:
						data["origin_node"].get_node("TextureRect/Stack").set_text("")
				elif data["target_stack"] != null and data["target_stack"] > 1 and data["origin_panel"] != "CharacterInterface":
					data["origin_node"].get_node("../TextureRect/Stack").set_text(str(data["target_stack"]))
				elif data["target_stack"] != null and data["target_stack"] > 1 and data["origin_panel"] == "CharacterInterface":
					data["origin_node"].get_node("TextureRect/Stack").set_text(str(data["target_stack"]))
				elif data["origin_panel"] == "Inventory" or data["origin_panel"] == "TradeInventory":
					data["origin_node"].get_node("../TextureRect/Stack").set_text("")
				elif data["origin_node"].get_parent().get_name() == "Hotbar":
					data["origin_node"].get_node("TextureRect/Stack").set_text("")
				
			# Update the texture, label and data of the target
			# stacking
			if (data["target_item_id"] == data["origin_item_id"] and data["origin_stackable"] and 
			(data["target_stack"] + data["origin_stack"] <= Constants.MAX_STACK_SIZE and split + data["target_stack"] <= Constants.MAX_STACK_SIZE)):
				var new_stack = 0
				if split != 0:
					new_stack = split
				else:
					new_stack = data["target_stack"] + data["origin_stack"]
				if new_stack > Constants.MAX_STACK_SIZE:
						new_stack = Constants.MAX_STACK_SIZE
				PlayerData.inv_data[target_slot]["Stack"] = new_stack
				get_node("../TextureRect/Stack").set_text(str(new_stack))
			else:
				# swaping
				PlayerData.inv_data[target_slot]["Item"] = data["origin_item_id"]
				verify_target_texture(data)
				get_child(0).frame = data["origin_frame"]
				get_child(0).texture = data["origin_texture"]
				if split != 0:
					data["origin_stack"] = split
				else: 
					data["origin_stack"] = data["origin_stack"]
				PlayerData.inv_data[target_slot]["Stack"] = data["origin_stack"]
				if data["origin_stack"] != null and data["origin_stack"] > 1:
					get_node("../TextureRect/Stack").set_text(str(data["origin_stack"]))
				else:
					get_node("../TextureRect/Stack").set_text("")
				swap = true
			hide_tooltip()
			show_tooltip()
			check_cooldown(data)
			show_hide_stack_label(data)
			split = 0


func SplitStack(split_amount, data):
	var target_slot = get_parent().get_name()
	var origin_slot = data["origin_node"].get_parent().get_name()
	var player_gold = int(Utils.get_current_player().get_gold())
	var valid = true
	var new_stack_size
	if data["target_stack"] != null and data["target_stack"] + split_amount > Constants.MAX_STACK_SIZE:
		split_amount = Constants.MAX_STACK_SIZE - data["target_stack"]
	# paying in case of buying and selling
	if data["origin_panel"] == "TradeInventory":
		if int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) * split_amount <= player_gold:
			Utils.get_trade_inventory().get_sound_player().stop()
			Utils.get_trade_inventory().get_sound_player().stream = Constants.PreloadedSounds.Collect
			Utils.get_trade_inventory().get_sound_player().play(0.03)
			Utils.get_current_player().set_gold(player_gold - (int(GameData.item_data[str(data["origin_item_id"])]["Worth"]) * split_amount))
			valid = true
		else:
			valid =  false
		Utils.get_trade_inventory().find_node("Inventory").get_child(0).find_node("Gold").set_text(
			"Gold: " + str(Utils.get_current_player().get_gold()))
	# update only when payed
	if valid:
		if data["origin_panel"] == "TradeInventory":
			if MerchantData.inv_data[origin_slot]["Stack"] != 0:
				MerchantData.inv_data[origin_slot]["Stack"] = data["origin_stack"] - split_amount
				MerchantData.inv_data[origin_slot]["Time"] = DayNightCycle.get_passed_days_since_start() * DayNightCycle.COMPLETE_DAY_TIME + DayNightCycle.get_current_time()
				check_slots()
		elif data["origin_panel"] == "Inventory":
			PlayerData.inv_data[origin_slot]["Stack"] = data["origin_stack"] - split_amount
		else:
			PlayerData.equipment_data[origin_slot]["Stack"] = data["origin_stack"] - split_amount
			Utils.get_hotbar().update_label()
		PlayerData.inv_data[target_slot]["Item"] = data["origin_item_id"]
		if data["target_stack"] != null:
			new_stack_size = data["target_stack"] + split_amount
		else:
			new_stack_size = split_amount
		PlayerData.inv_data[target_slot]["Stack"] = new_stack_size
		verify_target_texture(data)
		get_child(0).texture = data["origin_texture"]
		get_child(0).frame = data["origin_frame"]
		# origin label
		if data["origin_panel"] != "CharacterInterface":
			if data["origin_stack"] - split_amount > 1:
				data["origin_node"].get_node("../TextureRect/Stack").set_text(str(data["origin_stack"] - split_amount))
			else:
				data["origin_node"].get_node("../TextureRect/Stack").set_text("")
		else:
			if data["origin_stack"] - split_amount > 1:
				data["origin_node"].get_node("TextureRect/Stack").set_text(str(data["origin_stack"] - split_amount))
			else:
				data["origin_node"].get_node("TextureRect/Stack").set_text("")
		# target label
		if new_stack_size > 1:
			get_node("../TextureRect/Stack").set_text(str(new_stack_size))
		else:
			get_node("../TextureRect/Stack").set_text("")
		
		check_cooldown(data)
		show_hide_stack_label(data)


func show_hide_stack_label(data):
	if data["origin_panel"] != "CharacterInterface" and data["origin_panel"] != "Delete":
		if (int(data["origin_node"].get_parent().get_node("TextureRect/Stack").get_text()) > 1 and 
		data["origin_node"].get_parent().get_node("TextureRect/Stack").get_text() != null):
			data["origin_node"].get_parent().get_node("TextureRect").visible = true
		else:
			data["origin_node"].get_parent().get_node("TextureRect").visible = false
		if (int(get_parent().get_node("TextureRect/Stack").get_text()) > 1 and 
		get_parent().get_node("TextureRect/Stack").get_text() != null):
			get_parent().get_node("TextureRect").visible = true
		else:
			get_parent().get_node("TextureRect").visible = false
	else:
		if data["origin_node"].get_parent().get_name() != "Light" and data["origin_node"].get_parent().get_name() != "Weapon":
			if (int(data["origin_node"].get_node("TextureRect/Stack").get_text()) > 1 and 
			data["origin_node"].get_node("TextureRect/Stack").get_text() != null):
				data["origin_node"].get_node("TextureRect").visible = true
			else:
				data["origin_node"].get_node("TextureRect").visible = false
			if (int(get_parent().get_node("TextureRect/Stack").get_text()) > 1 and 
			get_parent().get_node("TextureRect/Stack").get_text() != null):
				get_parent().get_node("TextureRect").visible = true
			else:
				get_parent().get_node("TextureRect").visible = false


func verify_origin_texture(data):
	if data["target_item_id"] != null:
		if data["origin_panel"] == "TradeInventory" or data["origin_panel"] == "Inventory" or data["origin_panel"] == "Delete":
			if GameData.item_data[str(data["target_item_id"])]["Texture"] == "item_icons_1":
				data["origin_node"].get_child(0).set_scale(Vector2(1.5,1.5))
				data["origin_node"].get_child(0).set_hframes(16)
				data["origin_node"].get_child(0).set_vframes(27)
			else:
				data["origin_node"].get_child(0).set_scale(Vector2(2.5,2.5))
				data["origin_node"].get_child(0).set_hframes(13)
				data["origin_node"].get_child(0).set_vframes(15)
		else:
			if GameData.item_data[str(data["target_item_id"])]["Texture"] == "item_icons_1":
				data["origin_node"].get_child(0).set_scale(Vector2(2.5,2.5))
				data["origin_node"].get_child(0).set_hframes(16)
				data["origin_node"].get_child(0).set_vframes(27)
			else:
				data["origin_node"].get_child(0).set_scale(Vector2(4.5,4.5))
				data["origin_node"].get_child(0).set_hframes(13)
				data["origin_node"].get_child(0).set_vframes(15)
	
	
func verify_target_texture(data):
	if data["origin_item_id"] != null:
		if GameData.item_data[str(data["origin_item_id"])]["Texture"] == "item_icons_1":
			get_child(0).set_scale(Vector2(1.5,1.5))
			get_child(0).set_hframes(16)
			get_child(0).set_vframes(27)
		else:
			get_child(0).set_scale(Vector2(2.5,2.5))
			get_child(0).set_hframes(13)
			get_child(0).set_vframes(15)


# ToolTips
func _on_Icon_mouse_entered():
	show_tooltip()

func _on_Icon_mouse_exited():
	hide_tooltip()
	
	
func show_tooltip():
	var tool_tip_instance = tool_tip.instance()
	tool_tip_instance.origin = "Inventory"
	tool_tip_instance.slot = get_parent().get_name()
	
	tool_tip_instance.rect_position = get_parent().get_global_transform_with_canvas().origin + Vector2(64,64)
	
	add_child(tool_tip_instance)
	if has_node("ToolTip") and get_node("ToolTip").valid:
		get_node("ToolTip").show()

func hide_tooltip():
	get_node("ToolTip").free()
	
	
func check_slots():
	var free = false
	var free2 = false
	var trade = Utils.get_trade_inventory().get_trade_gridcontainer()
	var slots = MerchantData.inv_data.size()
	for i in MerchantData.inv_data:
		if MerchantData.inv_data[i]["Item"] == null:
			free = true
	if !free:
		Utils.set_and_play_sound(Constants.PreloadedSounds.OpenUI2)
		for i in range(slots+1,slots +7):
			var inv_slot_new = inv_slot.instance()
			MerchantData.inv_data["Inv" + str(i)] = {"Item":null,"Stack":null, "Time":null}
			inv_slot_new.set_name("Inv" + str(i))
			trade.add_child(inv_slot_new)
		MerchantData.save_merchant_inventory()
		Utils.save_game(true)
	elif slots > 30:
		for i in range(0,6):
			if MerchantData.inv_data["Inv" + str(MerchantData.inv_data.size() - i)]["Item"] != null:
				free2 = true
		if !free2:
			Utils.set_and_play_sound(Constants.PreloadedSounds.OpenUI2)
			slots = MerchantData.inv_data.size()
			for i in range(0,6):
				MerchantData.inv_data.erase("Inv" + str(slots - i))
				var inv_slot_empty = trade.get_node("Inv" + str(slots - i))
				trade.remove_child(inv_slot_empty)
				inv_slot_empty.queue_free()
			MerchantData.save_merchant_inventory()
			Utils.save_game(true)
			check_slots()


# Use Item
func _on_Icon_gui_input(event):
	if Utils.get_trade_inventory() == null:
		if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
			var slot = get_parent().get_name()
			if PlayerData.inv_data[slot]["Item"] != null and !disabled:
				if GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]["Category"] in ["Potion", "Food"]:
					if PlayerData.inv_data[slot]["Stack"] != null:
						PlayerData.inv_data[slot]["Stack"] -= 1
						var cooldown
						if GameData.item_data[str(PlayerData.inv_data[slot]["Item"])].has("Stamina"):
							Utils.get_current_player().set_current_stamina(Utils.get_current_player().player_stamina + 
							GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]["Stamina"])
							type = "Stamina"
							cooldown = Constants.STAMINA_POTION_COOLDOWN
							Utils.get_current_player().set_stamina_cooldown(cooldown)
							Utils.set_and_play_sound(Constants.PreloadedSounds.Potion)
						else:
							Utils.get_current_player().set_current_health(int(Utils.get_current_player().get_current_health()) + 
							int(GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]["Health"]))
							type = "Health"
							cooldown = Constants.HEALTH_COOLDOWN
							Utils.get_current_player().set_health_cooldown(cooldown)
							if GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]["Category"] == "Potion":
								Utils.set_and_play_sound(Constants.PreloadedSounds.Potion1)
							else:
								Utils.set_and_play_sound(Constants.PreloadedSounds.Eat)
						if PlayerData.inv_data[slot]["Stack"] > 0:
							set_cooldown(cooldown, type)
						if PlayerData.inv_data[slot]["Stack"] <= 0:
							PlayerData.inv_data[slot]["Stack"] = null
							PlayerData.inv_data[slot]["Item"] = null
							get_node("../TextureRect/Stack").set_text("")
							get_node("../TextureRect").visible = false
							get_node("../Icon/Sprite").set_texture(null)
						elif PlayerData.inv_data[slot]["Stack"] == 1:
							get_node("../TextureRect/Stack").set_text("")
							get_node("../TextureRect").visible = false
						else:
							get_node("../TextureRect/Stack").set_text(str(PlayerData.inv_data[slot]["Stack"]))
						# sync cooldown
						Utils.get_character_interface().find_node("Inventory").set_cooldown(cooldown, type)
						var cooldown_type = type
						if PlayerData.equipment_data["Hotbar"]["Item"] != null:
							if (GameData.item_data[str(PlayerData.equipment_data["Hotbar"]["Item"])].has(type) and 
								GameData.item_data[str(PlayerData.equipment_data["Hotbar"]["Item"])][type] != null):
								Utils.get_character_interface().find_node("Hotbar").get_node("Icon").set_cooldown(cooldown, type)
								if PlayerData.equipment_data["Hotbar"]["Item"] == null:
									Utils.get_hotbar().update_label()
								if type == "Stamina":
									Utils.get_hotbar().set_cooldown_stamina(cooldown, type)
								elif type == "Health":
									Utils.get_hotbar().set_cooldown_health(cooldown, type)
								cooldown_type = ""
						if type == "Stamina" and cooldown_type != "":
							Utils.get_hotbar().set_cooldown_stamina(cooldown, "")
						elif type == "Health" and cooldown_type != "":
							Utils.get_hotbar().set_cooldown_health(cooldown, "")
						hide_tooltip()
						show_tooltip()
				elif GameData.item_data[str(PlayerData.inv_data[slot]["Item"])]["Category"] == "Map" and !Utils.get_ui().has_map:
					Utils.set_and_play_sound(Constants.PreloadedSounds.Equip)
					Utils.get_ui().has_map = true
					Utils.get_minimap().set_visible(true)
					PlayerData.inv_data[slot]["Item"] = null
					PlayerData.inv_data[slot]["Stack"] = null
					get_node("../Icon/Sprite").set_texture(null)
					hide_tooltip()
					show_tooltip()


# starts cooldwon
func set_cooldown(cooldown, new_type):
	type = new_type
	timer.wait_time = cooldown
	timer.start()
	disabled = true
	set_process(true)
	time_label.show()


# cooldown by move an item
func check_cooldown(data):
	if data["origin_panel"] == "Delete":
		if GameData.item_data[str(data["origin_item_id"])].has("Stamina"):
			if Utils.get_current_player().stamina_cooldown > 0:
				timer.wait_time = Utils.get_current_player().stamina_cooldown
				start_timer()
			else:
				stop_timer()
		elif GameData.item_data[str(data["origin_item_id"])]["Health"] != null:
			if Utils.get_current_player().health_cooldown > 0:
				timer.wait_time = Utils.get_current_player().health_cooldown
				start_timer()
			else:
				stop_timer()
	elif (data["origin_panel"] != "TradeInventory" and data["origin_node"].get_parent().get_name() != "Light" and 
	data["origin_node"].get_parent().get_name() != "Weapon"):
		var cooldown
		var cooldown_origin
		if stack:
			cooldown = 0
			cooldown_origin = timer.time_left
			stack = false
		elif swap:
			cooldown = timer.time_left
			cooldown_origin = data["origin_node"].get_node("../Timer").time_left
			swap = false
		else:
			cooldown = data["origin_node"].get_node("../Timer").time_left
			cooldown_origin = data["origin_node"].get_node("../Timer").time_left
		if cooldown_origin != 0:
			timer.wait_time = cooldown_origin
			start_timer()
		else:
			stop_timer()
		if cooldown != 0:
			data["origin_node"].get_node("../Timer").wait_time = cooldown
			data["origin_node"].get_node("../Timer").start()
			data["origin_node"].disabled = true
			data["origin_node"].get_node("TextureProgress/Time").show()
			data["origin_node"].set_process(true)
		else:
			data["origin_node"].get_node("../Timer").stop()
			data["origin_node"].disabled = false
			data["origin_node"].get_node("TextureProgress").value = 0
			data["origin_node"].get_node("TextureProgress/Time").hide()
			data["origin_node"].set_process(false)
		if data["origin_slot"].has("Stamina"):
			type = "Stamina"
		elif data["origin_slot"].has("Health") and data["origin_slot"]["Health"] != null:
			type = "Health"
		if data["target_item_id"] != null:
			if GameData.item_data[str(data["target_item_id"])].has("Stamina"):
				data["origin_node"].type = "Stamina"
			elif GameData.item_data[str(data["target_item_id"])]["Health"] != null:
				data["origin_node"].type = "Health"
	

func start_timer():
	timer.start()
	disabled = true
	set_process(true)
	time_label.show()


func stop_timer():
	timer.stop()
	disabled = false
	set_process(false)
	time_label.hide()
	cooldown_texture.value = 0
