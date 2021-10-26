extends Node2D

const AIR_RESISTANCE_CONSTANT = 0.000000000001
const PRESSURE_DROPOFF = 0.1
const EXHAUST_SPREAD_SPEED = 1000
const SKY_COLOR = Color(0.4, 0.65, 1)

var altitude = 0 # Kilometers
var velocity = Vector2.ZERO # Meters per second
var temp = 23.0 # Celcius
var pressure = 101325.0 # Pascals

onready var root = get_parent()
onready var rocket_assembly = $RocketAssembly
onready var boss = $RocketAssembly/Boss
onready var ground_sprites = [$Ground/Ground1, $Ground/Ground2, $Ground/Ground3]
onready var ground_collision = $Ground/CollisionShape2D
onready var camera = $RocketAssembly/Boss/Camera2D
onready var exhaust = $RocketAssembly/Boss/Exhaust
onready var gui = $RocketAssembly/Boss/Camera2D/GUI
onready var stat_labels = $RocketAssembly/Boss/Camera2D/GUI/Stats/VBoxContainer.get_children()
onready var fuel_label = $RocketAssembly/Boss/Camera2D/GUI/Fuel/VBoxContainer/Label
onready var lox_gauge = $RocketAssembly/Boss/Camera2D/GUI/Fuel/VBoxContainer/VBoxContainer/LOX
onready var lh2_gauge = $RocketAssembly/Boss/Camera2D/GUI/Fuel/VBoxContainer/VBoxContainer/LH2
onready var orbit_progress_bar = $RocketAssembly/Boss/Camera2D/GUI/Progress/HBoxContainer/ProgressBar
onready var money_label = $RocketAssembly/Boss/Camera2D/GUI/Money/Label
#onready var star_bg = $RocketAssembly/Boss/Camera2D/GUI/Stars

func _ready():
	randomize()
	# set camera zoom to fit the rocket
	var needed_cam_size = 400
	camera.zoom.y = needed_cam_size / get_viewport_rect().size.y
	camera.zoom.x = camera.zoom.y
	
	# set the GUI to be the right size and shape to match the camera
	var gui_margin = get_viewport_rect().size / 2
	gui.margin_left = -gui_margin.x
	gui.margin_top = -gui_margin.y
	gui.margin_right = gui_margin.x
	gui.margin_bottom = gui_margin.y
	gui.rect_pivot_offset = gui_margin
	gui.rect_scale = camera.zoom
	
	# set the fuel indicators to the right sizes and positions
#	lox_gauge.rect_scale = Vector2(5,5)
#	lh2_gauge.rect_scale = Vector2(5,5)
#	lh2_gauge.rect_position.y = 30 * 5

func _process(delta):
	# change the fuel status stuff
	if rocket_assembly.stages != []: fuel_label.text = "Stage " + String(rocket_assembly.stages.size()) + " Fuel"
	
	# if boss is not directly over the middle ground sprite, move one of the side ground sprites to the other side
	if abs(boss.position.x - ground_sprites[1].position.x) > 192 and altitude < 10:
		var sprite_to_push
		if boss.position.x < ground_sprites[1].position.x:
			ground_sprites[2].position.x -= 1152
			ground_collision.position.x -= 384
			sprite_to_push = ground_sprites[2]
			ground_sprites.remove(2)
			ground_sprites.insert(0, sprite_to_push)
		else:
			ground_sprites[0].position.x += 1152
			ground_collision.position.x += 384
			sprite_to_push = ground_sprites[0]
			ground_sprites.remove(0)
			ground_sprites.append(sprite_to_push)
	
	camera.global_rotation = 0
	
	altitude = -boss.position.y / 1000
	velocity = boss.linear_velocity
	pressure = 101325 * exp(-PRESSURE_DROPOFF * altitude)
	
	for stage in rocket_assembly.get_children():
		if stage is RigidBody2D:# and stage != boss:
			if altitude < 160:
				stage.linear_damp = 0.01 * pow(pressure, 0.1)
				stage.angular_damp = 0.5 * pow(pressure, 0.1)
			else:
				stage.linear_damp = 0
				stage.angular_damp = 0
	exhaust.spread = 55 * exp(-pressure / EXHAUST_SPREAD_SPEED)
	
	# set the status labels
	stat_labels[0].text = "Altitude: " + String(stepify(altitude, 0.02)) + " km"
	stat_labels[1].text = "X Velocity: " + String(stepify(velocity.x, 0.02)) + " m/s"
	stat_labels[2].text = "Y Velocity: " + String(stepify(-velocity.y, 0.02)) + " m/s"
	stat_labels[3].text = "Speed: " + String(stepify(velocity.length(), 0.02)) + " m/s"
	stat_labels[4].text = "Acceleration: " + String(stepify(rocket_assembly.acceleration/9.81, 0.1)) + " g"
	stat_labels[5].text = "Temperature: " + String(stepify(temp, 0.02)) + " °C"
	stat_labels[6].text = "Pressure: " + String(stepify(pressure, 0.02)) + " Pa"
	
	# air resistance
	temp = 23 + AIR_RESISTANCE_CONSTANT * abs(0.1 + sin(boss.linear_velocity.angle_to(Vector2.UP.rotated(boss.rotation)))) * pow(boss.linear_velocity.length(), 4) * pressure
	
	# setting background color to match altitude
	if altitude < 100: VisualServer.set_default_clear_color(SKY_COLOR.linear_interpolate(Color.black, altitude/100))
	else: VisualServer.set_default_clear_color(Color.black)
	
	# setting default gravity to make it like an orbit
	if altitude > 0.5:#fmod(stepify(altitude,2), 1) == 0:
		ProjectSettings.set_setting("physics/2d/default_gravity", 398613890000000 / pow(6378100 + altitude, 2) - pow(boss.linear_velocity.x, 2) / (6378100 + 1000*altitude))
	
	# check if in orbit
#	print(ProjectSettings.get_setting("physics/2d/default_gravity"))
#	if ProjectSettings.get_setting("physics/2d/default_gravity") < 0: print("YOU WIN")
	
	# change orbit progress bar
	orbit_progress_bar.value = 100 - pow(ProjectSettings.get_setting("physics/2d/default_gravity"), 2)
	
	# change money label
	money_label.text = "MONEY\n$" + String(rocket_assembly.money_raised + root.money)


func _on_Win_confirmed():
	root.stages = []
	root.money = 0
	get_parent().add_child(load("res://Scenes/MainMenu.tscn").instance())
	get_parent().remove_child(self)

func _on_Lose_confirmed():
	get_parent().add_child(load("res://Scenes/RocketMenu.tscn").instance())
	get_parent().remove_child(self)

func _on_GameOver_confirmed():
	root.stages = []
	root.money = 0
	get_parent().add_child(load("res://Scenes/MainMenu.tscn").instance())
	get_parent().remove_child(self)
