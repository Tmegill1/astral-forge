class_name HUD
extends CanvasLayer
## Always-on-screen info: the hero panel (name, health, stats, carried
## resources), the Command Core (health, stored resources), the interact
## prompt, the respawn countdown, and the operating panel while the hero
## controls a tower. Later phases add wave info.

@onready var hero_name: Label = %HeroName
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_text: Label = %HealthText
@onready var stats_text: Label = %StatsText
@onready var level_text: Label = %LevelText
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_text: Label = %XpText
@onready var core_health_bar: ProgressBar = %CoreHealthBar
@onready var core_health_text: Label = %CoreHealthText
@onready var carried_text: Label = %CarriedText
@onready var stored_text: Label = %StoredText
@onready var carried_aether_text: Label = %CarriedAetherText
@onready var stored_aether_text: Label = %StoredAetherText
@onready var prompt: Label = %Prompt
@onready var respawn_text: Label = %RespawnText
@onready var operate_panel: PanelContainer = %OperatePanel
@onready var operate_title: Label = %OperateTitle
@onready var operate_stats: Label = %OperateStats
@onready var ability_text: Label = %AbilityText
@onready var wave_title: Label = %WaveTitle
@onready var wave_status: Label = %WaveStatus
@onready var sector_warnings: SectorWarnings = %SectorWarnings
@onready var boss_bar: BossBar = $BossBar
@onready var wave_banner: WaveBanner = $WaveBanner

var _hero: Hero
var _director: WaveDirector


func _process(_delta: float) -> void:
	_update_wave_panel()
	var tower := _hero.operating if _hero else null
	operate_panel.visible = tower != null
	if tower == null:
		return
	var def := tower.definition
	operate_title.text = ("Operating %s (Evolved)" % def.display_name) if def.evolved \
			else "Operating %s Lv%d" % [def.display_name, tower.level]
	operate_stats.text = "Damage %.0f · %.1f shots/s · Range %.0f" % [
		tower.damage(), tower.fire_rate(), tower.attack_range()]
	if tower.ability_active_left() > 0.0:
		ability_text.text = "%s active: %.1fs" % [def.ability_name, tower.ability_active_left()]
	elif tower.ability_cooldown_left() > 0.0:
		ability_text.text = "%s%s recharging: %ds" % [Settings.key_hint(&"tower_ability"), def.ability_name, ceili(tower.ability_cooldown_left())]
	else:
		ability_text.text = "%s%s ready" % [Settings.key_hint(&"tower_ability"), def.ability_name]


func bind_waves(director: WaveDirector) -> void:
	_director = director
	sector_warnings.director = director
	director.wave_started.connect(func(number: int) -> void:
		var wave := director.run.waves[number - 1]
		wave_banner.show_text(wave.banner if wave.banner != "" else "Wave %d" % number, wave.banner_outline))


func _update_wave_panel() -> void:
	if _director == null:
		return
	var total := _director.wave_count()
	match _director.state:
		WaveDirector.State.BREAK:
			var left := ceili(_director.break_left)
			wave_title.text = "Wave %d / %d" % [_director.wave_index + 1, total]
			var start := "tap WAVE to start now" if Settings.touch_mode \
					else Settings.key_hint(&"start_wave") + "start now"
			wave_status.text = "Arrives in %d:%02d  ·  %s" % [left / 60, left % 60, start]
		WaveDirector.State.WAVE:
			wave_title.text = "Wave %d / %d" % [_director.wave_index + 1, total]
			wave_status.text = "Goblins left: %d" % _director.enemies_left()
		WaveDirector.State.WON:
			wave_title.text = "All %d waves cleared" % total
			wave_status.text = ""


func bind_hero(hero: Hero) -> void:
	_hero = hero
	hero_name.text = hero.definition.display_name
	var show_stats := func() -> void:
		var s := hero.stats
		stats_text.text = "Damage %.0f   Fire rate %.1f/s\nSpeed %.0f   Range %.0f" % [
			s.attack_damage, s.attacks_per_second, s.move_speed, s.attack_range]
	hero.stats_changed.connect(show_stats)
	show_stats.call()
	_bind_bar(hero.health, health_bar, health_text)
	var show_carried := func() -> void:
		carried_text.text = "Carrying %d" % hero.carried.get_amount(Loot.SCRAP)
		carried_aether_text.text = str(hero.carried.get_amount(Loot.AETHER))
	hero.carried.changed.connect(show_carried)
	show_carried.call()
	hero.interact_prompt_changed.connect(func(text: String) -> void: prompt.text = text)
	prompt.text = ""


func bind_run_cards(cards: RunCards) -> void:
	var update := func() -> void:
		var needed := RunCards.xp_for_level(cards.level)
		level_text.text = "Lv %d" % cards.level
		xp_bar.max_value = needed
		xp_bar.value = cards.xp
		xp_text.text = "%d / %d XP" % [cards.xp, needed]
	cards.xp_changed.connect(update)
	update.call()


func bind_core(core: CommandCore) -> void:
	_bind_bar(core.health, core_health_bar, core_health_text)
	var show_stored := func() -> void:
		stored_text.text = "Stored %d" % core.stored.get_amount(Loot.SCRAP)
		stored_aether_text.text = str(core.stored.get_amount(Loot.AETHER))
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
