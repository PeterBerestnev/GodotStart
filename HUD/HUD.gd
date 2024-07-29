extends Control

onready var level = $VBoxContainer/GridContainer/LevelValue
onready var wave = $VBoxContainer/GridContainer/WaveValue
onready var health = $VBoxContainer/GridContainer2/HealthValue
onready var ammo = $VBoxContainer/GridContainer2/AmmoValue

#Health
#Ammo

func _ready():
	pass # Replace with function body.

func update_level(current_level):
	level.text = String(current_level + 1)


func _on_Spawner_wave_update(current_wave):
	wave.text = String(current_wave + 1)


func _on_Stats_update_health(current_HP, max_HP):
	health.text = String(current_HP)

func _on_GunController_ammo_update(ammo_value):
	ammo.text = String(ammo_value)
