class_name GatlingTower
extends Tower
## The Gatling Engine (an evolved Gearshot): spins up while it keeps firing,
## from 1× to 4× fire rate over 2 s, each shot weaker, and winds down over
## 1 s once it stops. Its gun turns to face any direction, like the Gearshot.
## Q = Overspin: full spin at once, held for the ability's duration.

## Still counts as firing this long past the gap to its next shot.
const SPIN_GRACE := 0.1

var gatling: GatlingDefinition
## 0 = still, 1 = full spin.
var spin := 0.0
var _since_shot := INF


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


func _fire_at(point: Vector2) -> void:
	super(point)
	_since_shot = 0.0
