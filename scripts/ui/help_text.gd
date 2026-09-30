class_name HelpText
extends RefCounted
## Words for the Help screen, built from tower and enemy data: numbers for
## towers (costs and bonuses), word ratings for enemies (no numbers).

const TYPES: Array[String] = ["Physical", "Fire", "Magic"]


## 1.3 -> "+30%".
static func percent(multiplier: float) -> String:
	return "+%d%%" % roundi((multiplier - 1.0) * 100.0)


## {"aether": 3, "scrap": 25} -> "25 Scrap + 3 Aether" (Scrap first).
static func cost_text(cost: Dictionary) -> String:
	var types: Array = cost.keys()
	types.sort_custom(func(a: StringName, b: StringName) -> bool:
		return (0 if a == &"scrap" else 1) < (0 if b == &"scrap" else 1))
	var parts: PackedStringArray = []
	for type in types:
		parts.append("%d %s" % [cost[type], Loot.display_name(type)])
	return " + ".join(parts) if not parts.is_empty() else "Free"


## "+35% damage, +50% fire rate, +15% range"; multipliers of 1 are left out.
static func operated_line(t: TowerDefinition) -> String:
	return _bonuses([[t.operated_damage_multiplier, "damage"],
			[t.operated_fire_rate_multiplier, "fire rate"],
			[t.operated_range_multiplier, "range"]])


static func upgrade_lines(t: TowerDefinition) -> PackedStringArray:
	var bonus := _bonuses([[t.level_damage_multiplier, "damage"],
			[t.level_fire_rate_multiplier, "fire rate"],
			[t.level_range_multiplier, "range"],
			[t.level_health_multiplier, "health"]])
	return PackedStringArray([
		"Lv1 — Build: %s" % cost_text(t.cost),
		"Lv2 — %s: %s" % [cost_text(t.lv2_cost), bonus],
		"Lv3 — %s: %s (again)" % [cost_text(t.lv3_cost), bonus],
	])


static func tower_bbcode(t: TowerDefinition) -> String:
	var lines: PackedStringArray = [t.description, ""]
	lines.append("[b]Damage:[/b] " + t.damage_type_label)
	lines.append("[b]Good against:[/b] " + t.good_against)
	lines.append("[b]Weak against:[/b] " + t.weak_against)
	lines.append("")
	lines.append("[b]Ability (while operated):[/b] %s — %s (Cooldown: %s s)" % [
			t.ability_name, t.ability_text, _number(t.ability_cooldown)])
	var operated := operated_line(t)
	if operated != "":
		lines.append("[b]Operated:[/b] " + operated)
	lines.append("")
	lines.append("[b]Upgrade path[/b]")
	for line in upgrade_lines(t):
		lines.append("  " + line)
	return "\n".join(lines)


## `value` compared with `base`: "Low", "Average", "High" or "Very high".
static func rating(value: float, base: float) -> String:
	var ratio := value / base if base > 0.0 else 1.0
	if ratio < 0.8:
		return "Low"
	if ratio <= 1.5:
		return "Average"
	if ratio <= 2.5:
		return "High"
	return "Very high"


## "Health: High · Speed: Low · Hits: Average", compared with `base`.
static func glance(e: EnemyDefinition, base: EnemyDefinition) -> String:
	return "Health: %s · Speed: %s · Hits: %s" % [
		rating(e.max_health, base.max_health),
		rating(e.move_speed, base.move_speed),
		rating(e.attack_damage * e.attacks_per_second, base.attack_damage * base.attacks_per_second),
	]


static func resistance_strengths(e: EnemyDefinition) -> PackedStringArray:
	var lines: PackedStringArray = []
	var taken := _taken(e)
	for i in TYPES.size():
		if taken[i] <= 0.5:
			lines.append("Shrugs off %s damage" % TYPES[i])
		elif taken[i] < 1.0:
			lines.append("Resists %s damage" % TYPES[i])
	return lines


static func resistance_weaknesses(e: EnemyDefinition) -> PackedStringArray:
	var taken := _taken(e)
	var lowest: float = taken.min()
	var highest: float = taken.max()
	if lowest >= 1.0 or is_equal_approx(lowest, highest):
		return PackedStringArray()
	var weak: PackedStringArray = []
	for i in TYPES.size():
		if is_equal_approx(taken[i], highest):
			weak.append(TYPES[i])
	return PackedStringArray(["Weak to " + " and ".join(weak)])


static func enemy_bbcode(e: EnemyDefinition, base: EnemyDefinition) -> String:
	var lines: PackedStringArray = [e.codex_summary, ""]
	lines.append("[b]At a glance:[/b] " + glance(e, base))
	var strengths := resistance_strengths(e) + e.codex_strengths
	if not strengths.is_empty():
		lines.append("")
		lines.append("[b]Strengths[/b]")
		for line in strengths:
			lines.append("  • " + line)
	var weaknesses := resistance_weaknesses(e) + e.codex_weaknesses
	if not weaknesses.is_empty():
		lines.append("")
		lines.append("[b]Weaknesses[/b]")
		for line in weaknesses:
			lines.append("  • " + line)
	if e.codex_tip != "":
		lines.append("")
		lines.append("[b]Tip:[/b] " + e.codex_tip)
	return "\n".join(lines)


static func _bonuses(pairs: Array) -> String:
	var parts: PackedStringArray = []
	for pair in pairs:
		if not is_equal_approx(pair[0], 1.0):
			parts.append("%s %s" % [percent(pair[0]), pair[1]])
	return ", ".join(parts)


static func _taken(e: EnemyDefinition) -> Array[float]:
	return [e.physical_taken, e.fire_taken, e.magic_taken]


## 12.0 -> "12", 2.5 -> "2.5".
static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
