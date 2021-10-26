extends Control

const SIZE_PRICE_FACTOR = 25
const ENGINE_COST = 250

onready var root = get_parent()
onready var sliders = $HBoxContainer/VBoxContainer/Panel/VBoxContainer/HBoxContainer.get_children()
onready var displays = $HBoxContainer/VBoxContainer/Panel/VBoxContainer/HBoxContainer3.get_children()
onready var texture_container = $HBoxContainer/VBoxContainer2/TextureContainer
onready var boss = $HBoxContainer/VBoxContainer2/TextureContainer/Boss

onready var add_edit_button = $HBoxContainer/VBoxContainer/Panel/VBoxContainer/AddEdit
onready var edit_button = $HBoxContainer/VBoxContainer/Panel/VBoxContainer/Edit
onready var remove_button = $HBoxContainer/VBoxContainer/Panel/VBoxContainer/Remove
onready var money_label = $HBoxContainer/VBoxContainer/Panel/VBoxContainer/Money
onready var up_button = $HBoxContainer/VBoxContainer2/HBoxContainer/Up
onready var down_button = $HBoxContainer/VBoxContainer2/HBoxContainer/Down

var stages = []#Stage.new(2.0, 10.0, 3.0), Stage.new(3.0, 20.0, 9.0)]
var proposed_stages = []
var money
var selected_stage = 0 # starts at 0, increases by 1 for every stage, -1 means no selection
var next_launch_site_scene

func _ready():
#	next_launch_site_scene = load("res://Scenes/World.tscn").instance()
	for stage in root.stages:
		stages.append(Stage.new(stage.tank_radius, stage.tank_height, stage.engine_count))
	money = root.money
	
	for i in displays.size(): displays[i].text = String(sliders[i].value)
	
	for stage in stages: proposed_stages.append(Stage.new(stage.tank_radius, stage.tank_height, stage.engine_count))
	
	if stages == []:
		for slider in sliders: slider.value = slider.min_value
		stages = [Stage.new(sliders[0].value, sliders[1].value, sliders[2].value)]
		proposed_stages = [Stage.new(sliders[0].value, sliders[1].value, sliders[2].value)]
	else:
		sliders[0].value = stages[selected_stage].tank_radius
		sliders[1].value = stages[selected_stage].tank_height
		sliders[2].value = stages[selected_stage].engine_count
	
	selected_stage = stages.size() - 1
	
	draw_rocket_display()

func _process(delta):
	var cost_sign = "-"
	if get_cost(stages[selected_stage], proposed_stages[selected_stage]) < 0: cost_sign = "+"
	edit_button.text = "EDIT STAGE (" + cost_sign + "$" + String(abs(get_cost(stages[selected_stage], proposed_stages[selected_stage]))) + ")"
	
	add_edit_button.disabled = money < 500 or stages.size() > 1
	edit_button.disabled = money < get_cost(stages[selected_stage], proposed_stages[selected_stage])# or (get_cost(stages[selected_stage], proposed_stages[selected_stage]) == 0)
	remove_button.disabled = (stages.size() == 1)
	up_button.disabled = (selected_stage == 0)
	down_button.disabled = selected_stage >= stages.size() - 1
	
	sliders[2].max_value = stepify(pow(proposed_stages[selected_stage].tank_radius, 2), 1)

func draw_rocket_display():
	# clear the effects of this being called previously
	for child in texture_container.get_children(): if child != boss: texture_container.remove_child(child)
	boss.scale = Vector2(0.08, 0.08)
	
	# find the total height and width of the rocket on display
	var total_height = boss.texture.get_height() * boss.scale.y
	var total_width = proposed_stages[0].tank_radius * 2
	for stage in proposed_stages:
		total_height += stage.tank_height
		total_width = max(stage.tank_radius * 2, total_width)
	var sprite_scale_factor = min(texture_container.rect_size.y / total_height, texture_container.rect_size.x / total_width)
	
	# draw the stages onto the menu for player viewing
	var mid_position = texture_container.rect_size.x / 2
	var boss_position = -boss.texture.get_height() * sprite_scale_factor * boss.scale.y / 2
	for i in stages.size():
		boss_position -= proposed_stages[i].tank_height * sprite_scale_factor
		
		var stage_sprite = Sprite.new()
		texture_container.add_child(stage_sprite)
		
		stage_sprite.position = Vector2(mid_position, texture_container.rect_size.y - proposed_stages[i].tank_height * sprite_scale_factor / 2)
		for j in range(i+1, stages.size()): stage_sprite.position.y -= proposed_stages[j].tank_height * sprite_scale_factor
		
		var stage_texture = GradientTexture.new()
		stage_texture.gradient = preload("res://Scenes/StageGradient.tres")
		stage_texture.width = 2
		stage_sprite.texture = stage_texture
		stage_sprite.scale = Vector2(proposed_stages[i].tank_radius, proposed_stages[i].tank_height) * sprite_scale_factor
	
	if texture_container.get_child(selected_stage + 1) != boss:
		texture_container.get_child(selected_stage + 1).texture.gradient = preload("res://Scenes/HighlightedStageGradient.tres")
	
	boss.position = Vector2(mid_position, texture_container.rect_size.y + boss_position)
	boss.scale *= sprite_scale_factor
	
	money_label.text = "MONEY: $" + String(money)

func change_values(stage):
	sliders[0].value = stage.tank_radius
	sliders[1].value = stage.tank_height
	sliders[2].value = stage.engine_count

func get_cost(current, proposed):
	if proposed == null or current == null: return 0
	
	var total_cost = 0
	if proposed.tank_radius > current.tank_radius:
		total_cost += pow(proposed.tank_radius - current.tank_radius, 2)
	else: total_cost -= pow(proposed.tank_radius - current.tank_radius, 2)
	total_cost += proposed.tank_height - current.tank_height
	total_cost *= SIZE_PRICE_FACTOR
	total_cost += ENGINE_COST * (proposed.engine_count - current.engine_count)
	return stepify(total_cost, 1)

func equalize_stages(changed, setter):
	changed[selected_stage].tank_radius = setter[selected_stage].tank_radius
	changed[selected_stage].tank_height = setter[selected_stage].tank_height
	changed[selected_stage].engine_count = setter[selected_stage].engine_count

func _on_TankRadius_value_changed(value):
	displays[0].text = String(value)
	if proposed_stages != []: proposed_stages[selected_stage].tank_radius = value
	draw_rocket_display()

func _on_TankHeight_value_changed(value):
	displays[1].text = String(value)
	if proposed_stages != []: proposed_stages[selected_stage].tank_height = value
	draw_rocket_display()

func _on_EngineCount_value_changed(value):
	displays[2].text = String(value)
	if proposed_stages != []: proposed_stages[selected_stage].engine_count = value
	draw_rocket_display()

func _on_Launch_pressed():
	root.stages = stages
	root.money = money
	get_parent().add_child(preload("res://Scenes/World.tscn").instance())
	get_parent().remove_child(self)

func _on_Up_pressed():
	equalize_stages(proposed_stages, stages)
	selected_stage -= 1
	change_values(stages[selected_stage])
	draw_rocket_display()

func _on_Down_pressed():
	equalize_stages(proposed_stages, stages)
	selected_stage += 1
	change_values(stages[selected_stage])
	draw_rocket_display()

func _on_AddEdit_pressed():
	equalize_stages(proposed_stages, stages)
	
	selected_stage = stages.size()
	stages.append(Stage.new(sliders[0].min_value, sliders[1].min_value, sliders[2].min_value))
	proposed_stages.append(Stage.new(sliders[0].min_value, sliders[1].min_value, sliders[2].min_value))
	
	remove_button.disabled = false
	money -= 500
	draw_rocket_display()
	change_values(stages[selected_stage])

func _on_Edit_pressed():
	money -= get_cost(stages[selected_stage], proposed_stages[selected_stage])
	equalize_stages(stages, proposed_stages)
	draw_rocket_display()

func _on_Remove_pressed():
	money += 500
	stages.remove(selected_stage)
	proposed_stages.remove(selected_stage)
	selected_stage -= 1
	change_values(stages[selected_stage])
	draw_rocket_display()
	
	if stages.size() == 1: remove_button.disabled = true
