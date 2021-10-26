extends Node

var stages = []
var money = 0

func _ready():
	add_child(preload("res://Scenes/MainMenu.tscn").instance())
