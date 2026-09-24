extends Node
## Run-wide state that survives scene changes (autoloaded as "Game").
## A hero-select screen will set selected_hero; until then it's the Artificer.

var selected_hero: HeroDefinition = preload("res://data/heroes/artificer.tres")
