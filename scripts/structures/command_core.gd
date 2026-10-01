class_name CommandCore
extends StaticBody2D
## The heart of the fortress. Enemies march on it; when its health hits
## zero the run is lost. Its look changes as it takes damage, and it slowly
## regenerates (regen_amount every regen_interval seconds). It also banks
## resources: heroes deposit what they carry here with Interact. Manage (F)
## opens the hero upgrade menu; ranks are paid from stored resources.

signal destroyed

@export var max_health := 500.0
## How far from the centre enemies can hit it from, in pixels.
@export var hit_radius := 95.0
## Health regained every regen_interval seconds while the Core stands.
@export var regen_amount := 10.0
## Seconds between regeneration ticks. 0 turns regeneration off.
@export var regen_interval := 5.0
@export var intact_texture: Texture2D
@export var damaged_texture: Texture2D
@export var ruined_texture: Texture2D

## Deposited resources; this is what building spends.
var stored := ResourceBag.new()

var _regen_left := 0.0

## Everything deposited here this run, by type (for the end-of-run summary).
var gathered: Dictionary[StringName, int] = {}

@onready var sprite: Sprite2D = $Sprite
@onready var health: Health = $Health


func _ready() -> void:
	health.changed.connect(_on_health_changed)
	health.died.connect(destroyed.emit)
	health.reset(max_health)
	_regen_left = regen_interval


func _process(delta: float) -> void:
	if regen_interval <= 0.0 or health.is_dead:
		return
	_regen_left -= delta
	if _regen_left <= 0.0:
		_regen_left += regen_interval
		if health.current < health.max_health:
			health.heal(regen_amount)


## Solid area for enemy pathfinding: its body circle.
func nav_footprint() -> Rect2:
	var r: float = ($Body.shape as CircleShape2D).radius
	return Rect2(global_position - Vector2(r, r), Vector2(r, r) * 2.0)


func interact(hero: Hero) -> void:
	var deposit := hero.carried.take_all()
	for type in deposit:
		gathered[type] = gathered.get(type, 0) + deposit[type]
	stored.add_all(deposit)


func get_interact_prompt(hero: Hero) -> String:
	var parts: PackedStringArray = []
	if not hero.carried.is_empty():
		parts.append("[E] Deposit %s" % hero.carried.describe())
	if not hero.definition.upgrades.is_empty():
		parts.append("[F] Upgrade hero")
	return "    ".join(parts)


func manage(hero: Hero) -> void:
	if not hero.definition.upgrades.is_empty():
		get_tree().call_group(&"hero_upgrade_menu", &"open", self, hero)


## Pays for the next rank of `upgrade` from stored resources and gives it to
## the hero. False if it's maxed or unaffordable (nothing is spent then).
func buy_upgrade(hero: Hero, upgrade: HeroUpgrade) -> bool:
	var rank := hero.rank_of(upgrade)
	if rank >= upgrade.max_rank() or not stored.spend_all(upgrade.cost_for(rank + 1)):
		return false
	hero.add_rank(upgrade)
	return true


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := current / maximum
	if ratio > 0.66:
		sprite.texture = intact_texture
	elif ratio > 0.33:
		sprite.texture = damaged_texture
	else:
		sprite.texture = ruined_texture


## Re-applies Core Plating to max health (adds the difference to current).
func refresh_max_health() -> void:
	var target := max_health * RunCards.multiplier(self, &"core_max_health")
	if not health.is_dead and not is_equal_approx(health.max_health, target):
		health.grow_max(target)
