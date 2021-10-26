extends Node2D

const GIMBAL = PI/36.0
const ENGINE_STARTUP_TIME_CONSTANT = 3 # half the time it takes to start the engine
const STAGE_SEP_KICK = 150 # force provided after stage separation
const STABLIZATION_CONSTANT = 1 # proportionality constant for the stablizing torque
const FORCE_CONST = 5 # factor of engine force
const FUEL_CONST = 1.5 # how quickly fuel runs out
const ZOOM_TIME = 2
const MONEY_FACTOR = 5000

var stages = []
var acceleration = 0 # in m/s^2
var prev_velocity = null
var engine_startup = 0 # between 0 and 0.5, engine is starting up; between 0.5 and 1, engine is throttling between 50% and 100%
var current_fuel_volume
var money_raised = 0

onready var root = get_parent().get_parent()
onready var world = get_parent()
onready var camera = $Boss/Camera2D
onready var gui = $Boss/Camera2D/GUI
onready var boss = $Boss
onready var exhaust = $Boss/Exhaust
onready var sonic_boom = $Boss/SonicBoom
onready var explosion = $Boss/Explosion
onready var zoom_tween = $Boss/Zoom
onready var pin_joints = $Boss/PinJoints
onready var fuel_label = $Boss/Camera2D/GUI/Fuel/VBoxContainer/Label
onready var gauge_container = $Boss/Camera2D/GUI/Fuel/VBoxContainer/VBoxContainer
onready var lox_gauge = $Boss/Camera2D/GUI/Fuel/VBoxContainer/VBoxContainer/LOX
onready var lh2_gauge = $Boss/Camera2D/GUI/Fuel/VBoxContainer/VBoxContainer/LH2
onready var win_dialog = $Boss/Camera2D/GUI/CanvasLayer/Win
onready var lose_dialog = $Boss/Camera2D/GUI/CanvasLayer/Lose
onready var game_over_dialog = $Boss/Camera2D/GUI/CanvasLayer/GameOver

func _ready():
	gui.rect_size = get_viewport_rect().size * camera.zoom
	
	pin_joints.global_position = Vector2.ZERO
	
	# initialize stages and create exhaust extents accordingly
#	stages = root.stages#[Stage.new(9.0,50.0,9.0), Stage.new(10.0,70.0,33.0)]
	for stage in root.stages:
		stages.append(Stage.new(stage.tank_radius, stage.tank_height, stage.engine_count))
	
	if 2 * stages.back().engine_count < stages.back().tank_radius * 3:
		exhaust.emission_rect_extents = Vector2(1,1) * stages.back().engine_count
	else: exhaust.emission_rect_extents = Vector2(1.75, 1.75) * stages.back().tank_radius
	exhaust.scale_amount = exhaust.emission_rect_extents.x / 400
	
	# create the rocket rigidbodies, collision shapes, pinjoints, and sprites
	var temp_stage_rigidbody
	var first_stage_rigidbody
	var boss_position = -get_collision(boss).shape.extents.y
	var boss_pin1
	var boss_pin2
	for i in stages.size():
		boss_position -= stages[i].tank_height
		
		var stage_rigidbody = RigidBody2D.new()
		if i == 0: first_stage_rigidbody = stage_rigidbody
		var stage_collision = CollisionShape2D.new()
		var stage_sprite = Sprite.new()
		
		add_child(stage_rigidbody)
		stage_rigidbody.add_child(stage_collision)
		stage_rigidbody.add_child(stage_sprite)
		stage_rigidbody.mass = pow(stages[i].tank_radius, 2) * stages[i].tank_height / 600
		
		var collision_shape = RectangleShape2D.new()
		collision_shape.extents = Vector2(stages[i].tank_radius, stages[i].tank_height/2)
		stage_collision.shape = collision_shape
		stage_collision.position = Vector2.ZERO
		
		var pin_joint1 = PinJoint2D.new()
		var pin_joint2 = PinJoint2D.new()
		if i == 0:
			boss_pin1 = pin_joint1
			boss_pin2 = pin_joint2
		pin_joint1.position = Vector2(500 - 5 * stages[i].tank_radius, 24-stages[i].tank_height)
		pin_joint2.position = Vector2(500 + 5 * stages[i].tank_radius, 24-stages[i].tank_height)
		
		stage_rigidbody.position = Vector2(0, -stages[i].tank_height / 2)
		for j in range(i+1, stages.size()):
			pin_joint1.position.y -= stages[j].tank_height
			pin_joint2.position.y -= stages[j].tank_height
			stage_rigidbody.position.y -= stages[j].tank_height
		
		for pj in [pin_joint1, pin_joint2]:
			pj.bias = 0
			pj.softness = 0
			pj.disable_collision = false
			pin_joints.add_child(pj)
			if temp_stage_rigidbody != null:
				pj.node_a = temp_stage_rigidbody.get_path()
				pj.node_b = stage_rigidbody.get_path()
			pj.disable_collision = true
		temp_stage_rigidbody = stage_rigidbody
		
		var stage_texture = GradientTexture.new()
		stage_texture.gradient = preload("res://Scenes/StageGradient.tres")
		stage_texture.width = 2
		stage_sprite.texture = stage_texture
		stage_sprite.scale = Vector2(stages[i].tank_radius, stages[i].tank_height)
	boss.position = Vector2(0, boss_position)
	boss_pin1.node_a = boss.get_path()
	boss_pin2.node_a = boss.get_path()
	boss_pin1.node_b = first_stage_rigidbody.get_path()
	boss_pin2.node_b = first_stage_rigidbody.get_path()
	
	# initialize fuel data
#	gauge_container.rect_scale = Vector2(5,5)
#	gauge_container.rect_pivot_offset = Vector2(107,0)
	current_fuel_volume = PI * pow(stages.back().tank_radius,2) * stages.back().tank_height

func _process(delta):
	# determine rocket acceleration
	if prev_velocity == null: prev_velocity = boss.linear_velocity
	else:
		acceleration = (((boss.linear_velocity-prev_velocity) / delta) - Vector2(0,10)).length()
		prev_velocity = null
	
	# start/throttle engine
	if Input.is_action_pressed("engine_startup"):
		if engine_startup < 1: engine_startup += delta / ENGINE_STARTUP_TIME_CONSTANT
	elif engine_startup > 0: engine_startup -= delta / ENGINE_STARTUP_TIME_CONSTANT
	
	# shut off the engines in preparation of stage separation
	if Input.is_action_pressed("separate_stage"): engine_startup = 0
	
	exhaust.global_rotation = 0
	sonic_boom.global_rotation = 0
	
	# determine the amount of raised money
	money_raised = stepify(MONEY_FACTOR * (10 - ProjectSettings.get_setting("physics/2d/default_gravity")), 0.01)
	
	# change the fuel stuff
	if stages != []:
		lox_gauge.value = stepify(100 * current_fuel_volume / (PI * pow(stages.back().tank_radius,2) * stages.back().tank_height), 1)
		lh2_gauge.value = stepify(100 * current_fuel_volume / (PI * pow(stages.back().tank_radius,2) * stages.back().tank_height), 1)

func _physics_process(delta):
	var active_stage_rb
	if stages != []: active_stage_rb = get_child(stages.size() - 1)
	else: active_stage_rb = boss
	
	# change back stage's mass based on fuel volume
	get_children().back().mass = current_fuel_volume / (600 * PI) + 0.05
	
	# check for keypresses and apply forces accordingly
	active_stage_rb.applied_force = Vector2.ZERO
	active_stage_rb.applied_torque = 0
	var thrust_rotation = 0
	if Input.is_action_pressed("pivot_counterclockwise"): thrust_rotation -= GIMBAL
	if Input.is_action_pressed("pivot_clockwise"): thrust_rotation += GIMBAL
	var normalized_direction_vector = Vector2.UP.rotated(active_stage_rb.rotation)
	if engine_startup >= 0.5 and stages != [] and current_fuel_volume > 0:
		# zoom to the right position every time the engines start up
		if abs(engine_startup - 0.5) < delta / ENGINE_STARTUP_TIME_CONSTANT: zoom_to(Vector2(5,5) * abs(get_active_engines_position()) / 1024)
		
		exhaust.emitting = true
		active_stage_rb.add_force(get_active_engines_position() * -normalized_direction_vector, FORCE_CONST * stages.back().engine_count * engine_startup * normalized_direction_vector.rotated(thrust_rotation))
		current_fuel_volume -= FUEL_CONST * stages.back().engine_count * engine_startup * delta
	else: exhaust.emitting = false
	
	# stablize the rocket
	var total_mass = boss.mass
	for child in get_children():
		if child is RigidBody2D: total_mass += child.mass
#	active_stage_rb.add_torque(-active_stage_rb.applied_torque)
#	boss.add_torque(STABLIZATION_CONSTANT * pow(total_mass, 0.025) * pow(boss.linear_velocity.length(), 1.5) * sin(normalized_direction_vector.angle_to(boss.linear_velocity)))
	
	# emit sonic boom if going the right speed
	sonic_boom.emitting = world.velocity.length() > 343 and world.velocity.length() < 347
	
	# customize particle exhaust
	exhaust.global_position = get_active_engines_position() * normalized_direction_vector + boss.global_position
	exhaust.direction = (-normalized_direction_vector).rotated(-thrust_rotation)
	sonic_boom.direction = -normalized_direction_vector
	exhaust.initial_velocity = 4000 * (engine_startup - 0.1)
	
	# do an explosion thing if applicable
	if world.temp > 2000:# or acceleration > 10 and abs(boss.position.x) > 0.001:
		var total_height = 0
		for stage in stages: total_height += stage.tank_height
		explosion.scale = Vector2(0.2, 0.2) * total_height
		explosion.position -= normalized_direction_vector * total_height / 2
		explosion.emitting = true
		for child in get_children(): if child != boss: child.visible = false
		get_tree().paused = true
		if not game_over_dialog.visible: game_over_dialog.popup()
	
	# check for stage separation
	if Input.is_action_just_released("separate_stage"):# and stages != []:
#		var og_engines_position = get_active_engines_position()
		if stages != []:
			for i in 2: pin_joints.remove_child(pin_joints.get_child(pin_joints.get_child_count() - 1))
			stages.remove(stages.size() - 1)
			boss.add_force(get_active_engines_position() * -normalized_direction_vector, STAGE_SEP_KICK * normalized_direction_vector)
		
		if stages.size() > 0:
			zoom_to(abs(get_active_engines_position()) * Vector2(5,5) / 1024.0)
#			camera.zoom = abs(get_active_engines_position()) * Vector2(5,5) / 1024.0
#			gui.rect_scale *= get_active_engines_position() / og_engines_position
			current_fuel_volume = PI * pow(stages.back().tank_radius,2) * stages.back().tank_height
		else:
			if ProjectSettings.get_setting("physics/2d/default_gravity") > 0:
				# try again with new money
				root.money += money_raised
				lose_dialog.popup()
			else:
				root.money += money_raised
				win_dialog.popup()

func zoom_to(zoom):
	var scale_factor = zoom.x / camera.zoom.x
	zoom_tween.interpolate_property(camera, "zoom", camera.zoom, zoom, ZOOM_TIME, Tween.TRANS_QUAD)
	zoom_tween.start()
	zoom_tween.interpolate_property(gui, "rect_scale", gui.rect_scale, gui.rect_scale * scale_factor, ZOOM_TIME, Tween.TRANS_QUAD)
	zoom_tween.start()

func get_collision(body):
	for child in body.get_children():
		if child.name == "CollisionShape2D" or child.name == "CollisionPolygon2D": return child
func get_sprite(body): return body.get_node("Sprite")

func get_active_engines_position():
	var active_engines_position = -get_collision(boss).shape.extents.y
	for stage in stages: active_engines_position -= stage.tank_height
	return active_engines_position
	
