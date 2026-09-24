class_name HUD
extends CanvasLayer
## Always-on-screen info: the hero panel (name, health, stats, carried
## resources), the Command Core (health, stored resources), the interact
## prompt and the respawn countdown. Later phases add wave info.

@onready var hero_name: Label = %HeroName
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_text: Label = %HealthText
@onready var stats_text: Label = %StatsText
@onready var core_health_bar: ProgressBar = %CoreHealthBar
@onready var core_health_text: Label = %CoreHealthText
@onready var carried_text: Label = %CarriedText
@onready var stored_text: Label = %StoredText
@onready var prompt: Label = %Prompt
@onready var respawn_text: Label = %RespawnText


func bind_hero(hero: Hero) -> void:
	hero_name.text = hero.definition.display_name
	var s := hero.stats
	stats_text.text = "Damage %.0f   Fire rate %.1f/s\nSpeed %.0f   Range %.0f" % [
		s.attack_damage, s.attacks_per_second, s.move_speed, s.attack_range]
	_bind_bar(hero.health, health_bar, health_text)
	var show_carried := func() -> void:
		carried_text.text = "Carrying %d" % hero.carried.get_amount(Loot.SCRAP)
	hero.carried.changed.connect(show_carried)
	show_carried.call()
	hero.interact_prompt_changed.connect(func(text: String) -> void: prompt.text = text)
	prompt.text = ""


func bind_core(core: CommandCore) -> void:
	_bind_bar(core.health, core_health_bar, core_health_text)
	var show_stored := func() -> void:
		stored_text.text = "Stored %d" % core.stored.get_amount(Loot.SCRAP)
	core.stored.changed.connect(show_stored)
	show_stored.call()


## Shows the countdown while the hero is down; pass 0 or less to hide it.
func show_respawn(seconds_left: float) -> void:
	respawn_text.visible = seconds_left > 0.0
	respawn_text.text = "Respawning at the Core in %d" % ceili(seconds_left)


## Keeps a bar, its "current / max" text and its colour in sync with a Health.
func _bind_bar(health: Health, bar: ProgressBar, text: Label) -> void:
	var fill := StyleBoxFlat.new()
	bar.add_theme_stylebox_override(&"fill", fill)
	var update := func(current: float, maximum: float) -> void:
		bar.max_value = maximum
		bar.value = current
		text.text = "%d / %d" % [ceili(current), ceili(maximum)]
		fill.bg_color = HealthBar.health_color(current / maximum)
	health.changed.connect(update)
	update.call(health.current, health.max_health)
