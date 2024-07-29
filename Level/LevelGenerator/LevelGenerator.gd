tool
extends Spatial

export var GroundScene: PackedScene
export var ObstacleScene: PackedScene 
export var navmesh_template: NavigationMesh
export var WaveScene: PackedScene

var shader_material : ShaderMaterial

export(int, 1, 31) var map_width = 11 setget set_width
export(int, 1, 31) var map_depth = 11 setget set_depth

export(float, 0, 1, 0.05) var obstacle_density = 0.2 setget set_obstacle_density
export(float, 1, 7) var obstacle_max_height = 7 setget set_max_obs_height
export(float, 1, 7) var obstacle_min_height = 1 setget set_min_obs_height

export(Color) var foreground_color: Color setget set_foreground_color
export(Color) var background_color: Color setget set_background_color

export(int) var rng_seed = 12345 setget set_seed

export(String) var level_name = "New Level"

export(bool) var generate_level = false setget set_generate_level
export(bool) var save_level = false setget set_save_level

var level: NavigationMap
var navmesh_instance: NavigationMeshInstance 
var wave_container: Node

func _ready():
	pass

func set_generate_level(new_val):
	generate_map()
	
func set_save_level(new_val):
	var packed_scene = PackedScene.new()
	navmesh_instance.owner = level
	for child in navmesh_instance.get_children():
		child.owner = level
	
	wave_container.owner = level
	for child in wave_container.get_children():
		child.owner = level
	
	packed_scene.pack(level)
	var scene_resource_path = "res://Level/LevelGenerator/GeneratedLevels/%s.tscn" % level_name
	ResourceSaver.save(scene_resource_path, packed_scene)
	
	level_name = increment_string(level_name)
	property_list_changed_notify()

func increment_string(string: String):
	var regex = RegEx.new()
	regex.compile("\\d+$")
	var result = regex.search(string)
	var num = "0"
	if result:
		num = result.get_string()
	
	return string.trim_suffix(num) + str(int(num) + 1)

func set_foreground_color(new_val):
	foreground_color = new_val
	
func set_background_color(new_val):
	background_color = new_val

func set_max_obs_height(new_val):
	obstacle_max_height = max(new_val, obstacle_min_height)
	
func set_min_obs_height(new_val):
	obstacle_min_height = min(new_val, obstacle_max_height)

func set_seed(var new_val):
	rng_seed = new_val

func set_width(var new_val):
	map_width = make_odd(new_val, map_width)
	
func set_depth(var new_val):
	map_depth = make_odd(new_val, map_depth)
	
func set_obstacle_density(new_val):
	obstacle_density = new_val

func make_odd(new_int, old_int):
	if new_int % 2 == 0:
		if new_int > old_int:
			return new_int + 1
		else:
			return new_int - 1
		pass
	else:
		return new_int
			
func fill_obstacle_map():
	level.obstacle_map = []
	for x in range(map_width):
		level.obstacle_map.append([])
		for z in range(map_depth):
			level.obstacle_map[x].append(false)

func generate_map():
	print("Generating new map ...")
	
	clear_map()
	add_level()
	level.update_map_center()
	add_ground()
	update_obstacle_material()
	add_obstacles()
	add_waves()
	
	set_seed(rng_seed + 1)
	property_list_changed_notify()

func add_waves():
	wave_container = Node.new()
	wave_container.name = "Waves"
	
	var wave = WaveScene.instance()
	wave_container.add_child(wave)
	
	level.add_child(wave_container)
	
	wave_container.owner = self
	wave.owner = self

func clear_map():
	for node in get_children():
		node.free()

func add_level():
	level = NavigationMap.new()
	level.name = "Navigation"
	add_child(level)
	level.owner = self
	
	level.map_depth = map_depth
	level.map_width = map_width
	
	#Add navmesh
	navmesh_instance = NavigationMeshInstance.new()
	level.add_child(navmesh_instance)
	navmesh_instance.owner = self
	
	# navmesh instance
	navmesh_instance.navmesh = navmesh_template.duplicate()
	
func add_ground():
	var ground: CSGBox = GroundScene.instance()
	ground.width = map_width * 2
	ground.depth = map_depth * 2
	navmesh_instance.add_child(ground)
	ground.owner = self

func update_obstacle_material():
	var temp_obstacle: CSGBox = ObstacleScene.instance()
	shader_material = temp_obstacle.material as ShaderMaterial
	shader_material.set_shader_param("ForegroundColor", foreground_color)
	shader_material.set_shader_param("BackgroundColor", background_color)
	shader_material.set_shader_param("LevelDepth", map_depth*2)

func add_obstacles():
	level.fill_map_coords_array()
	fill_obstacle_map()
#	print(map_coords_array)
	seed(rng_seed)
	level.map_coords_array.shuffle()
#	print(map_coords_array)
	
	var num_obstacles : int = level.map_coords_array.size() * obstacle_density
	var current_obstacle_count = 0
	
	if num_obstacles > 0:
		for coord in level.map_coords_array.slice(0, num_obstacles - 1):
			if not level.map_center.equals(coord):
				current_obstacle_count += 1
				level.obstacle_map[coord.x][coord.z] = true
				if map_is_fully_accessable(current_obstacle_count):
					create_obstacle_at(coord.x, coord.z)
				else:
					current_obstacle_count -= 1
					level.obstacle_map[coord.x][coord.z] = false
		

func map_is_fully_accessable(current_obstacle_count):
	#Flood Fill
	var already_checked = []
	for x in range(map_width):
		already_checked.append([])
		for z in range(map_depth):
			already_checked[x].append(false)
	
	var coords_to_check = [level.map_center]
	already_checked[level.map_center.x][level.map_center.z] = true
	var accessable_tile_count = 1
	
	while coords_to_check:
		var current_tile: NavigationMap.Coord = coords_to_check.pop_front()
		for x in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				if x == 0 or z == 0: #non-diagnol neghbour
					var neighbour = NavigationMap.Coord.new(current_tile.x + x, current_tile.z + z)
					if on_the_map(neighbour):
						if not already_checked[neighbour.x][neighbour.z]:
							if not level.obstacle_map[neighbour.x][neighbour.z]:
									already_checked[neighbour.x][neighbour.z] = true
									coords_to_check.append(neighbour)
									accessable_tile_count += 1

	var target_accessable_tile_count = map_width * map_depth - current_obstacle_count
	return target_accessable_tile_count == accessable_tile_count

func on_the_map(neighbour):
	return neighbour.x >= 0 and neighbour.x < map_width and neighbour.z >= 0 and neighbour.z < map_depth

func create_obstacle_at(x, z):
	var obstacle_position = Vector3(x * 2, 0, z * 2)
	obstacle_position += Vector3(- map_width + 1, 0, - map_depth + 1)
	var new_obstacle: CSGBox = ObstacleScene.instance()
	new_obstacle.height = get_obstacle_height()
	
	#New material, set color
#	var new_material := SpatialMaterial.new()
#	new_material.albedo_color = get_color_at_depth(z)
#	new_obstacle.material = new_material

	new_obstacle.transform.origin = obstacle_position + Vector3(0, new_obstacle.height/2 , 0)
	navmesh_instance.add_child(new_obstacle)
	new_obstacle.owner = self

func get_obstacle_height():
	return rand_range(obstacle_min_height, obstacle_max_height)

func get_color_at_depth(z):
	return background_color.linear_interpolate(foreground_color, float(z)/map_depth)
