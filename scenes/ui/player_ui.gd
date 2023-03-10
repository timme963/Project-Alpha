extends Control

onready var exp_bar = get_node("NinePatchRect/ProgressBar")
onready var clock = get_node("Clock/clock")
onready var exp_value = get_node("NinePatchRect/ProgressBar/EXPValue")
onready var life_bar = get_node("Lifebar")
onready var bossHpNode = get_node("BossHpBar")
onready var bossHpBar = get_node("BossHpBar/ProgressBar")
onready var bossName = get_node("BossHpBar/ProgressBar/BossName")
onready var stamina_bar = get_node("MarginContainer/MarginContainer/ProgressBar")
onready var progress = get_node("Quest/ProgressBar")

var hearts = 3
var boss
var minimum_progress_size = 210
var min_max_dif = 154
var quest_finished
var current_quest
var quest_progress


func _ready():
	# Setup bossHpBar at startup
	bossHpNode.visible = false
	bossHpBar.value = 100


# Load the correct ui settings
func setup_ui():
	var player_level = Utils.get_current_player().get_level()
	exp_bar.max_value = player_level * 100
	stamina_bar.max_value = Utils.get_current_player().get_max_stamina()
	set_stamina(Utils.get_current_player().get_current_stamina())
	stamina_bar.rect_min_size.x = minimum_progress_size + ((float(min_max_dif) / (Constants.MAX_LEVEL -1)) * player_level -1)
	if player_level >= 10:
			change_heart_number(5)
	elif player_level >= 5:
			change_heart_number(4)
	else:
		change_heart_number(3)
	var data = Utils.get_current_player().get_data()
	current_quest = data.quest
	quest_finished = data.quest_finished
	quest_progress = data.quest_progress
	if data.quest != "" and data.quest != null:
		set_quest(current_quest)
	else:
		quest_completed()
	set_quest_progress(0)
	set_quest_finished(quest_finished)


# Set stamina value 
func set_stamina(new_value: float):
	stamina_bar.value = new_value


# Set expbar value
func set_exp(new_value: int):
	exp_value.set_text("EXP: " + str(new_value))
	exp_bar.value = new_value
	# Max exp for level
	if exp_bar.value >= exp_bar.max_value:
		var player_level = Utils.get_current_player().get_level()
		# increase by level up
		if player_level < Constants.MAX_LEVEL:
			# Sound
			Utils.set_and_play_sound(Constants.PreloadedSounds.Levelup)
			# reset exp bar
			Utils.get_current_player().set_exp(new_value - player_level * 100)
			# increase by level up
			Utils.get_current_player().set_level(player_level +1)
			exp_bar.max_value = (player_level + 1) * 100
			stamina_bar.max_value = 100 + player_level * 10
			Utils.get_current_player().set_max_health(100 + player_level*10)
			Utils.get_current_player().set_max_stamina(100 + player_level * 10)
			player_level += 1
			# reset life and stamina
			if !Utils.get_current_player().is_player_dying():
				Utils.get_current_player().set_current_stamina(90 + player_level * 10)
				life_bar.value = 100
				Utils.get_current_player().set_current_health(90 + player_level * 10)
			# save player
			Utils.save_game(true)
			stamina_bar.rect_min_size.x = minimum_progress_size + ((float(min_max_dif) / Constants.MAX_LEVEL -1) * player_level -1)
			if player_level == 5:
				change_heart_number(4)
			elif player_level == 10:
				change_heart_number(5)
		else:
			exp_bar.value = exp_bar.max_value
			exp_value.set_text("EXP: " + str(exp_bar.value))

# Clock
func set_time(new_hour, new_minute):
	clock.set_text(str("%02d" % new_hour) + ":" + str("%02d" % new_minute))


# LifeBar its a % display
func set_life(percent_player_health: int):
	# Factor = 100 / 80 -> 20 = empty = 27-37, 62-72
	# 3 beacuse 3 hearts -> 1/3 each
	if hearts == 3:
		if percent_player_health < 34:
			life_bar.value = percent_player_health / 1.25
		elif percent_player_health < 66:
			# Minimum value from this heart + value - maxvalue of heart before / factor
			life_bar.value = 37 + (percent_player_health - 34) / 1.25
		else:
			# Minimum value from this heart + value - maxvalue of heart before / factor		
			life_bar.value = 72 + (percent_player_health - 66) / 1.25
	elif hearts == 4:
		if percent_player_health < 26:
			life_bar.value = percent_player_health / 1.25
		elif percent_player_health < 51:
			life_bar.value = 27 + (percent_player_health - 26) / 1.25
		elif percent_player_health < 76:
			life_bar.value = 53 + (percent_player_health - 51) / 1.25
		else:
			life_bar.value = 79 + (percent_player_health - 76) / 1.25
	elif hearts == 5:
		if percent_player_health < 22:
			life_bar.value = percent_player_health / 1.3
		elif percent_player_health < 41:
			life_bar.value = 23 + (percent_player_health - 22) / 1.3
		elif percent_player_health < 62:
			life_bar.value = 43 + (percent_player_health - 41) / 1.3
		elif percent_player_health < 81:
			life_bar.value = 64 + (percent_player_health - 62) / 1.3
		else:
			life_bar.value = 84 + (percent_player_health - 81) / 1.3


func change_heart_number(number_heart):
	hearts = number_heart
	life_bar.texture_under = load("res://assets/ui/lifebar_background_" + str(number_heart) + ".png")
	life_bar.texture_progress = load("res://assets/ui/lifebar_" + str(number_heart) + ".png")


# position for hotbar with or without minimap
func without_minimap(value):
	# Without minimap
	if (value or (!Utils.get_ui().has_map or !Utils.get_minimap().is_visible())):
		get_node("Hotbar").set_deferred("rect_position", Vector2(-916,456))
	# With minimap
	else:
		get_node("Hotbar").set_deferred("rect_position", Vector2(-504,456))


# Method to reset boss hp in ui
func show_boss_health_bar(is_visible):
	# Show boss health bar only in dungeon -> boss room
	if is_visible:
		bossHpNode.visible = true
		bossHpBar.value = 100
	else:
		bossHpNode.visible = false
		bossHpBar.value = 100
		bossName.set_text("")
		boss = null


# Method to set boss hp value in ui
func set_boss_health(healthbar_value_in_percent):
	bossHpBar.value = healthbar_value_in_percent


# Method to set boss_name to health bar text
func set_boss_name_to_hp_bar(new_boss):
	boss = new_boss
	bossName.set_text(boss.get_boss_name())


# Method to update language
func update_language():
	# Bossname
	if boss != null: # Boss is existing and name can be updated
		bossName.set_text(boss.get_boss_name())
	if current_quest != "" and current_quest != null:
		get_node("Quest/Title").set_text(tr(current_quest))
		get_node("Quest/Quest").set_text(tr(current_quest + "_TASK"))


func is_quest_finished():
	return quest_finished


func get_current_quest():
	return current_quest


# Called when quest task is done
func set_quest_finished(new_value):
	quest_finished = new_value
	if new_value:
		progress.value = progress.max_value
	save_quest()


# Called when player starts a quest by hugo or has a quest when enter the game
func set_quest(new_quest):
	current_quest = new_quest
	get_node("Quest").show()
	get_node("Quest/Title").set_text(tr(current_quest))
	get_node("Quest/Quest").set_text(tr(current_quest + "_TASK"))
	set_quest_progress(0)
	save_quest()


# Called when player gets quest reward or canceled
func quest_completed():
	quest_progress = 0
	progress.value = quest_progress
	current_quest = ""
	get_node("Quest/Title").set_text("")
	get_node("Quest/Quest").set_text("")
	quest_finished = false
	get_node("Quest").hide()
	save_quest()


# Save the quest when player has a quest or finished a quest
func save_quest():
	var data = Utils.get_current_player().get_data()
	data.quest_finished = quest_finished
	data.quest = current_quest
	data.quest_progress = quest_progress
	Utils.get_current_player().set_data(data)


func set_quest_progress(new_value):
	quest_progress += new_value
	progress.value = quest_progress
	if quest_progress >= 20: # 20 Mobs for Quest3
		Utils.set_and_play_sound(Constants.PreloadedSounds.Sucsess)
		set_quest_finished(true)
		quest_progress = 0
	save_quest()


# Method is called if enemy is killed
func on_enemy_killed():
	if get_current_quest() == "QUEST3" and !is_quest_finished():
		set_quest_progress(1)


# Method is called if boss is killed
func on_boss_killed():
	if get_current_quest() == "QUEST2" and !is_quest_finished():
		set_quest_finished(true)
	elif (get_current_quest() == "QUEST1" and !is_quest_finished() 
		and "Dungeon" in  Utils.get_scene_manager().current_transition_data.get_scene_path()):
		set_quest_finished(true)
	elif get_current_quest() == "QUEST3" and !is_quest_finished():
		set_quest_progress(1)
