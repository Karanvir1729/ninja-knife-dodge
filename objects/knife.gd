extends Area2D
## A dagger of light. Waits for its Start timer, then flies in a straight line.
## Sword sprite: https://opengameart.org/users/inog

var speed: float = 450.0
var direction: Vector2 = Vector2.RIGHT
var increment := false
var can_move := true
var _hit := false
var _near_counted := false

func _ready() -> void:
	$Start.start()

func _process(delta: float) -> void:
	if increment and can_move:
		position += direction * speed * delta

func set_glow(color: Color) -> void:
	$Glow.modulate = Color(color, 0.85)
	$SkeletonSword.modulate = Color(1, 1, 1, 1).lerp(color, 0.25)

func _on_start_timeout() -> void:
	increment = true

func _on_body_entered(body: Node) -> void:
	if body.name == "Player" and not _hit:
		_hit = true
		get_tree().call_group("playstate", "game_over")

func _on_off_screen_screen_exited() -> void:
	if not increment:
		return
	get_tree().call_group("playstate", "increment_score")
	queue_free()

func _on_near_miss_body_exited(body: Node) -> void:
	if body.name == "Player" and not _hit and not _near_counted and increment and can_move:
		_near_counted = true
		get_tree().call_group("playstate", "near_miss", global_position + direction * 46.0)
