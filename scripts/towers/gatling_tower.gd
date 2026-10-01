class_name GatlingTower
extends Tower
## The Gatling Engine (an evolved Gearshot): spins up while it keeps firing,
## from 1× to 4× fire rate over 2 s, each shot weaker, and winds down over
## 1 s once it stops. Faces left or right (mirrored art). Q = Overspin: full
## spin at once, held for the ability's duration.

## Still counts as firing this long past the gap to its next shot.
const SPIN_GRACE := 0.1

var gatling: GatlingDefinition
## 0 = still, 1 = full spin.
var spin := 0.0
var _since_shot := INF
var _facing_left := false


func _ready() -> void:
	gatling = definition as GatlingDefinition
	assert(gatling != null, "A GatlingTower needs a GatlingDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	_since_shot += delta
	if _ability_left > 0.0:
		spin = 1.0
	else:
		spin = gatling.spin_after(spin, delta, _since_shot <= 1.0 / fire_rate() + SPIN_GRACE)


func damage() -> float:
	return super() * gatling.shot_damage_multiplier


func fire_rate() -> float:
	return super() * gatling.spin_multiplier(spin)


func _aim_at(point: Vector2) -> void:
	_facing_left = point.x < global_position.x
	sprite.flip_h = _facing_left


func _muzzle_base() -> Vector2:
	var offset := gatling.muzzle_offset
	return global_position + Vector2(-offset.x if _facing_left else offset.x, offset.y)


func _fire_at(point: Vector2) -> void:
	super(point)
	_since_shot = 0.0
