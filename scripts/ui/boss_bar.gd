class_name BossBar
extends Control
## A wide health bar across the top while a boss is alive (the first one
## found in the "bosses" group), with its name above.

var boss: Enemy

@onready var name_label: Label = %BossName
@onready var bar: ProgressBar = %BossHealth


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or boss.health.is_dead or boss.fled:
		boss = null
		for node in get_tree().get_nodes_in_group(&"bosses"):
			var candidate := node as Enemy
			if candidate and not candidate.health.is_dead and not candidate.fled:
				boss = candidate
				break
	visible = boss != null
	if boss:
		name_label.text = boss.definition.display_name
		bar.max_value = boss.health.max_health
		bar.value = boss.health.current
