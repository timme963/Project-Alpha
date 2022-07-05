extends Node2D

var language

func _ready():
	# Say SceneManager that new_scene is ready
	Utils.get_scene_manager().finish_transition()
	# Sets the Langauge
	var save_settings = File.new()
	if save_settings.file_exists("user://settings.json"):
		save_settings.open("user://settings.json", File.READ)
		var settings = {}
		settings = parse_json(save_settings.get_line())
		save_settings.close()
		language = settings.language
	else:
		language = "en"
	Utils.set_language(language)
	TranslationServer.set_locale(language)
	# sets the text
	get_node("Start Game").set_text(tr("START_GAME"))
	get_node("Settings").set_text(tr("SETTINGS"))
	get_node("Exit to Desktop").set_text(tr("EXIT_TO_DESKTOP"))
	Utils.get_scene_manager().finish_transition()


func _on_Start_Game_pressed():
	var transition_data = TransitionData.Menu.new("res://scenes/menu/character_screens/CharacterScreen.tscn")
	Utils.get_scene_manager().transition_to_scene(transition_data)

func _on_Settings_pressed():
	Utils.get_scene_manager().get_child(0).add_child(load("res://scenes/menu/SettingScreen.tscn").instance())

func _on_Exit_to_Desktop_pressed():
	get_tree().quit()
