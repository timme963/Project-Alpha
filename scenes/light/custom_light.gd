extends Node2D
class_name CustomLight

# Variables
export(Color, RGBA) var color = Color("#64ffde7e")
export var radius = 20

# Constants
const MAX_LIGHT_STRENGTH = 0.7
const LIGHT_STRENGTH = 0.5
const MIN_LIGHT_STRENGTH = 0.4

# Nodes
onready var lightPosition = $LightPosition

# Light radius
var max_radius = radius * 1.04 # 104% of radius
var min_radius = radius * 0.96 # 96% of radius

# Light strength
var max_strength = MAX_LIGHT_STRENGTH
var strength = LIGHT_STRENGTH
var min_strength = MIN_LIGHT_STRENGTH

# Noise
var noise = OpenSimplexNoise.new()
var value = 0.0
const MAX_VALUE = 500

func _ready():
	max_radius = radius * 1.04 # 104% of radius
	min_radius = radius * 0.96 # 96% of radius
	randomize()
	value = randi() % MAX_VALUE
	
	# Setup noise
	noise.period = 120


func _physics_process(_delta):
	value += 1.0
	if (value > MAX_VALUE):
		value = 0.0
	
	# Set new light strength
	strength = abs(noise.get_noise_1d(value)) + min_strength
	if strength > max_strength:
		strength = max_strength
	
	# Set new light radius
	radius = abs(noise.get_noise_1d(value)) * radius + min_radius
	if radius > max_radius:
		radius = max_radius

# Method to hide the light
func hide_light():
	max_strength = 0.0
	strength = 0.0
	min_strength = 0.0

# Method to show the light
func show_light():
	max_strength = MAX_LIGHT_STRENGTH
	strength = LIGHT_STRENGTH
	min_strength = MIN_LIGHT_STRENGTH

#  Method to return position where the center of the light is
func get_light_position():
	return position + lightPosition.position
