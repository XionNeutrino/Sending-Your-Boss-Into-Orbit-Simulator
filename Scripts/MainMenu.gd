extends Control

onready var tutorial = $Tutorial
onready var credits = $Credits

func _ready():
	pass


func _on_Tutorial_pressed():
	tutorial.popup()


func _on_NewGame_pressed():
#	get_tree().change_scene("res://Scenes/RocketMenu.tscn")
	get_parent().add_child(preload("res://Scenes/RocketMenu.tscn").instance())
	get_parent().remove_child(self)


func _on_Credits_pressed():
	credits.popup()
