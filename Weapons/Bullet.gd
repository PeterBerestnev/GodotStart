extends Spatial

export var speed = 70

export var damage = 1

export(float) var kill_time = 2
var timer = 0

# Called when the node enters the scene tree for the first time.
func _physics_process(delta):
	var shot_direction = global_transform.basis.z.normalized()
	global_translate(shot_direction * speed * delta)
	
	timer += delta
	if timer > kill_time:
		queue_free()


func _on_Area_body_entered(body: Node):
	queue_free()
	
	if body.has_node("Stats"):
		var stats_node = body.find_node("Stats") as Stats
		stats_node.take_hit(damage)
