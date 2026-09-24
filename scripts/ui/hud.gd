class_name HUD
extends CanvasLayer
## Always-on-screen info. For now: the hero panel (name, health, stats).
## Later phases add Core health, resources and wave info here.

@onready var hero_name: Label = %HeroName
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_text: Label = %HealthText
@onready var stats_text: Label = %StatsText

var _fill := StyleBoxFlat.new()


func _ready() -> void:
	health_bar.add_theme_stylebox_override(&"fill", _fill)


func bind_hero(hero: Hero) -> void:
	hero_name.text = hero.definition.display_name
	var s := hero.stats
	stats_text.text = "Damage %.0f   Fire rate %.1f/s\nSpeed %.0f   Range %.0f" % [
		s.attack_damage, s.attacks_per_second, s.move_speed, s.attack_range]
	hero.health.changed.connect(_on_health_changed)
	_on_health_changed(hero.health.current, hero.health.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "%d / %d" % [ceili(current), ceili(maximum)]
	_fill.bg_color = HealthBar.health_color(current / maximum)
