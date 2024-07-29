extends Spatial

export(PackedScene) var Enemy
onready var timer = $Timer
var navmap: NavigationMap setget set_navmap

var enemies_remaining_to_spawn
var enemies_killed_current_wave

var waves # list of Wave Nodes: [Wave1, Wave2, Wave3, ... ] 
var current_wave: Wave
var current_wave_number = -1

signal level_complete
signal wave_update
signal drop_item

func set_navmap(new_navmap):
	navmap = new_navmap
	waves = navmap.get_waves()

func start_next_wave():
	enemies_killed_current_wave = 0
	current_wave_number += 1
	if current_wave_number < waves.size():
		emit_signal("wave_update", current_wave_number)
		current_wave = waves[current_wave_number]
		enemies_remaining_to_spawn = current_wave.num_enemies
		timer.wait_time = current_wave.second_between_spawns
		timer.start()
		
		if current_wave.should_drop(enemies_killed_current_wave):
			emit_signal("drop_item", current_wave.DropItem)
	else:
		#Level Complete
		emit_signal("level_complete")

func reset():
	current_wave_number = -1
	start_next_wave()

func spawn_enemy():
	#Spawn!
	var enemy = Enemy.instance()
	enemy.set_characteristics(
		current_wave.health,
		current_wave.damage,
		current_wave.move_speed
	)
	
	#Give enemy random position thats not an obstacle
	var location: Vector3 = navmap.get_random_empty_vector3()
	enemy.translate(Vector3(location.x, 0, location.z))
	
	enemy.set_navmap(navmap)
	
	connect_to_enemy_instance(enemy)
	var scene_root = get_parent()
	scene_root.add_child(enemy)
	enemies_remaining_to_spawn -= 1


func connect_to_enemy_instance(enemy: Enemy):
	var stats: Stats = enemy.get_node("Stats")
	stats.connect("you_died_signal", self, "_on_Enemy_Stats_you_died_signal")
	
func _on_Enemy_Stats_you_died_signal():
	enemies_killed_current_wave += 1
	print("Enemies killed: ", enemies_killed_current_wave)
	
	#check if item shoul be dropped
	if current_wave.should_drop(enemies_killed_current_wave):
		emit_signal("drop_item", current_wave.DropItem)

func _on_Timer_timeout():
	if enemies_remaining_to_spawn:
		spawn_enemy()
	else:
		if enemies_killed_current_wave == current_wave.num_enemies:
			start_next_wave()
