extends CanvasLayer

var dialogPath = null
var textSpeed = 0.05
var dialog
var trade = false
var phraseNum = 0
var finished = false
var obj_name
var origin
var type
var death = false


func start(origin_obj, looted_value, treasure_type):
	Utils.get_ui().is_dialog = true
	obj_name = origin_obj.name
	origin = origin_obj
	type = treasure_type
	if typeof(looted_value) != TYPE_BOOL and looted_value == "Death":
		dialog = treasure_type
		death = true
	elif typeof(looted_value) == TYPE_BOOL:
		if "treasure" in obj_name and !looted_value:
			obj_name = "treasure"
			if treasure_type == "1":
				get_node("Trade/Icon").frame = 185
			elif treasure_type == "2":
				get_node("Trade/Icon").frame = 186
			else:
				get_node("Trade/Icon").frame = 271
				get_node("Trade/Label").show()
				get_node("Trade/Label").set_text(tr("OPEN"))
				obj_name = "open"
		elif "treasure" in obj_name and looted_value:
			obj_name = "empty"
		else:
			if looted_value:
				obj_name = "quest"
				get_node("Quest/Icon").frame = 203
			else:
				get_node("Quest/Icon").frame = 218
				get_node("Trade/Icon").frame = 320
	else:
		obj_name = "open"
		get_node("Trade/Icon").frame = 271
		get_node("Trade/Label").show()
		get_node("Trade/Label").set_text(tr("OPEN"))
	Utils.get_control_notes().hide()
	$Timer.wait_time = textSpeed
	# Get language
	if !death:
		var lang = TranslationServer.get_locale()
		dialogPath = "res://assets/dialogue/"+ obj_name + "_" + lang + ".json"
		dialog = FileManager.load_dialog_data(dialogPath)
	nextPhrase()


func _process(_delta):
	$Skip.visible = finished
	if Input.is_action_just_pressed("e") and $Text.visible_characters > 2:
		Utils.set_and_play_sound(Constants.PreloadedSounds.Click)
		if finished:
			nextPhrase()
		else:
			$Text.visible_characters = len($Text.text)





func nextPhrase():
	# At the end of the dialog
	if phraseNum >= len(dialog):
		trade = false
		close_dialog()
	# Show text
	else:
		finished = false
		$Name.bbcode_text = dialog[phraseNum].name + ":"
		$Text.bbcode_text = dialog[phraseNum].text
		$Text.visible_characters = 0
		# Sound
		get_node("Sound").stop()
		get_node("Sound").stream = Constants.PreloadedSounds.Dialog
		get_node("Sound").play()
		while $Text.visible_characters < len($Text.text):
			$Text.visible_characters += 1
			$Timer.start()
			yield($Timer, "timeout")
		get_node("Sound").stop()
		finished = true
		phraseNum += 1
	
	# Show trade symbol
	if phraseNum >= len(dialog):
		if obj_name == "hugo" or obj_name == "quest":
			$Quest.visible = true
			trade = true
		if obj_name in ["bella", "sam", "lea", "heinz", "haley"]: # names of npc which can trade
			$Trade.visible = true
			trade = true
		elif "treasure" in obj_name or "open" in obj_name:
			$Trade.visible = true
			trade = true


func _on_Button_pressed():
	# Sound
	Utils.set_and_play_sound(Constants.PreloadedSounds.Click)
	if finished:
		nextPhrase()
		trade = false
	else:
		$Text.visible_characters = len($Text.text)


func close_dialog():
	$Trade.visible = false
	phraseNum = 0
	finished = false
	Utils.get_ui().is_dialog = false
	if !trade:
		Utils.get_current_player().set_player_can_interact(true)
		Utils.get_current_player().set_movement(true)
		Utils.get_current_player().set_movment_animation(true)
		Utils.get_current_player().pause_player(false)
		# reset npc interaction state
		if !death:
			if !"treasure" in obj_name and !"empty" in obj_name and !"open" in obj_name:
				for npc in origin.get_parent().get_children():
					npc.set_interacted(false)
			else:
				if type != "3":
					Utils.get_scene_manager().get_current_scene().reset_interaction()
				else:
					origin.reset_interaction()
	Utils.get_control_notes().show()
	queue_free()


# Open Quest list
func _on_Quest_pressed():
	Utils.set_and_play_sound(Constants.PreloadedSounds.OpenUI)
	Utils.get_control_notes().show()
	var quest = Constants.PreloadedScenes.QuestScene.instance()
	Utils.get_ui().add_child(quest)
	var success
	if obj_name == "hugo" or !Utils.get_player_ui().is_quest_finished():
		success = quest.show_quests()
	else:
		success = quest.reward_quest()
	if success:
		close_dialog()
	else:
		finished = false
		$Text.visible_characters = 0
		get_node("Sound").stop()
		get_node("Sound").stream = Constants.PreloadedSounds.Dialog
		get_node("Sound").play()
		$Text.bbcode_text = tr("REWARD_FULL")
		$Quest.visible = false
		trade = false
		while $Text.visible_characters < len(tr("REWARD_FULL")):
			$Text.visible_characters += 1
			$Timer.start()
			yield($Timer, "timeout")
		finished = true
		get_node("Sound").stop()


func _on_Trade_pressed():
	if !"treasure" in obj_name and !"empty" in obj_name and !"open" in obj_name:
		# Sound
		Utils.set_and_play_sound(Constants.PreloadedSounds.OpenUI2)
		Utils.get_control_notes().show()
		MerchantData.set_path(obj_name)
		MerchantData.load_merchant_data()
		PlayerData.load_player_data()
		close_dialog()
		# Show trade inventory
		Utils.get_ui().add_child(Constants.PreloadedScenes.TradeInventoryScene.instance())
		Utils.get_trade_inventory().set_name(obj_name)
	else:
		Utils.get_control_notes().show()
		if type != "3":
			if Utils.get_scene_manager().get_current_scene().player_has_key(origin):
				Utils.get_scene_manager().get_current_scene().open_loot_panel(origin)
			else:
				Utils.set_and_play_sound(Constants.PreloadedSounds.locked)
				trade = false
		else:
			origin.open_loot_panel()
		close_dialog()
