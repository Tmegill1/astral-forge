extends Node
## Which enemies the player has seen (autoloaded as "Codex"). An enemy is
## added the first time one comes on screen, saved to user://codex.cfg and
## kept across runs. Anything unreadable in the file counts as unseen.

signal discovered(definition: EnemyDefinition)

const PATH := "user://codex.cfg"
const ENEMY_DIR := "res://data/enemies/"

var _seen: Dictionary[StringName, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func is_seen(id: StringName) -> bool:
	return _seen.get(id, false)


## Records the first sighting of `definition`'s enemy type and announces it.
func mark_seen(definition: EnemyDefinition) -> void:
	if definition == null or is_seen(definition.id):
		return
	_seen[definition.id] = true
	_save()
	discovered.emit(definition)


## Every enemy type in data/enemies/, by name.
func all_enemies() -> Array[EnemyDefinition]:
	var enemies: Array[EnemyDefinition] = []
	for file in ResourceLoader.list_directory(ENEMY_DIR):
		if not file.ends_with(".tres"):
			continue
		var definition := load(ENEMY_DIR + file) as EnemyDefinition
		if definition:
			enemies.append(definition)
	enemies.sort_custom(func(a: EnemyDefinition, b: EnemyDefinition) -> bool:
		return a.display_name < b.display_name)
	return enemies


func _load() -> void:
	_seen.clear()
	var file := ConfigFile.new()
	if file.load(PATH) != OK or not file.has_section("seen"):
		return
	for key in file.get_section_keys("seen"):
		var value = file.get_value("seen", key)
		if value is bool and value:
			_seen[StringName(key)] = true


func _save() -> void:
	var file := ConfigFile.new()
	for id in _seen:
		file.set_value("seen", String(id), true)
	file.save(PATH)
