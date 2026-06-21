class_name HitResolver
extends RefCounted

## Resolves all attacks for one tick. Runs AFTER both fighters have advanced and after
## pushbox/stage resolution. Hitboxes are snapshotted before anything is applied so two
## fighters striking on the same tick can trade cleanly. Each victim is hit at most once
## per tick.

static func resolve(fighters: Array, projectiles: Array) -> void:
	var pending: Array = []

	# Melee hitboxes.
	for atk in fighters:
		if not atk.has_active_hitbox():
			continue
		var vic = atk.opponent
		if vic == null or not is_instance_valid(vic):
			continue
		if _overlaps(atk.active_hitbox(), vic.hurtboxes()):
			pending.append({"atk": atk, "vic": vic, "move": atk.current_move,
				"facing": atk.facing, "proj": null})

	# Projectiles.
	for p in projectiles:
		if p.connected:
			continue
		var vic = _fighter_for_side(fighters, 1 - p.owner_side)
		if vic == null:
			continue
		if _overlaps(p.aabb(), vic.hurtboxes()):
			pending.append({"atk": _fighter_for_side(fighters, p.owner_side), "vic": vic,
				"move": p.move, "facing": p.facing, "proj": p})

	# Apply, one hit per victim this tick.
	var hit_victims := {}
	for h in pending:
		if hit_victims.has(h["vic"]):
			continue
		hit_victims[h["vic"]] = true
		var bonus: int = 0
		if h["proj"] == null and h["atk"] != null and is_instance_valid(h["atk"]):
			bonus = h["atk"].drive_rush_hit_bonus()
		var blocked: bool = h["vic"].receive_attack(h["move"], h["facing"], bonus)
		if h["proj"] != null:
			h["proj"].connected = true
			if h["atk"] != null and not blocked:
				h["atk"].gain_meter(h["move"].meter_gain)
		else:
			h["atk"].mark_connected(blocked, h["move"])

static func _overlaps(box: AABB, boxes: Array[AABB]) -> bool:
	for b in boxes:
		if box.intersects(b):
			return true
	return false

static func _fighter_for_side(fighters: Array, side: int):
	for f in fighters:
		if f.side == side:
			return f
	return null
