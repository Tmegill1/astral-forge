extends SceneTree
## Headless checks that the bosses and evolved towers use their real art.
## Run: timeout 60 godot --headless --path . --script tests/test_art.gd
## Prints each failure and "art: N passed, M failed"; exits 1 on failure.

var passed := 0
var failed := 0


func _init() -> void:
	var warchief = load("res://data/enemies/goblin_warchief.tres")
	var king = load("res://data/enemies/goblin_shaman_king.tres")
	check_boss(warchief, [&"idle", &"walk", &"death", &"attack", &"war_cry", &"hurt"], [&"war_cry"])
	check_boss(king, [&"idle", &"walk", &"death", &"cast", &"projectile", &"summon", &"buff", &"phase_shift"],
			[&"summon", &"buff", &"phase_shift"])
	check("warchief pulse", warchief.pulse_animation, &"war_cry")
	check("warchief keeps aura", warchief.aura.a > 0.0, true)
	check("king summon anim", king.summon_animation, &"summon")
	check("king phase anim", king.phase_shift_animation, &"phase_shift")
	check("king pulse anim", king.pulse_animation, &"buff")
	check("king attack anim", king.attack_animation, &"cast")
	check("king no aura", king.aura.a, 0.0)
	check("king orb", king.projectile_scene.resource_path, "res://scenes/projectiles/king_orb.tscn")
	for def in [warchief, king]:
		check("%s portrait" % def.id, def.get("portrait") != null and def.portrait.resource_path
				== "res://assets/sprites/portraits/%s.png" % def.id, true)
	print("art: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## `channels` must exist and play once (a looping one never ends a channel).
func check_boss(def, anims: Array, channels: Array) -> void:
	var frames: SpriteFrames = def.sprite_frames
	check("%s frames" % def.id, frames.resource_path, "res://assets/sprites/%s.tres" % def.id)
	check("%s untinted" % def.id, def.tint, Color.WHITE)
	for anim in anims:
		check("%s has %s" % [def.id, anim], frames.has_animation(anim), true)
	for anim in channels:
		check("%s %s plays once" % [def.id, anim], frames.has_animation(anim) and not frames.get_animation_loop(anim), true)
	check("%s attack frame in range" % def.id,
			frames.has_animation(def.attack_animation)
			and def.attack_hit_frame < frames.get_frame_count(def.attack_animation), true)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
