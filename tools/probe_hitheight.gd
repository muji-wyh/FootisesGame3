extends SceneTree
## Checks every move's authored hitbox against where the animation actually strikes.
##
## For each move it replays the clip exactly the way AnimatedFighterRig does (seek + speed from
## attack_timing(), so the clip's measured impact lands on the move's first active frame), walks
## the striking limb across the WHOLE active window, and prints the limb's height and forward
## reach next to the box the simulation collides with. A "MISS" row means the box never contains
## the limb: the hitbox is drawn somewhere the kick/punch visibly is not.
##
##   godot4.7 --headless --path . --script res://tools/probe_hitheight.gd -- blaze
##
## Y is the axis to trust here: it should follow the animation. X (reach) is deliberately tuned
## for footsies spacing in tools/run_tests.gd, so treat the X columns as information, not a bug.

const TIPS := ["RightHand", "LeftHand", "RightFoot", "LeftFoot"]

var _skel: Skeleton3D
var _basis: Basis

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var ch := CharacterLibrary.create(args[0] if args.size() > 0 else "blaze")
	var model := (load(ch.model_path) as PackedScene).instantiate() as Node3D
	var ap := _find(model, "AnimationPlayer") as AnimationPlayer
	_skel = _find(model, "Skeleton3D") as Skeleton3D
	ap.add_animation_library("kb", AnimatedFighterRig.build_library(ch.rig))
	root.add_child(model)
	ap.clear_caches()
	var model_basis := Basis.from_euler((ch.model_euler_deg + Vector3(0, ch.model_face_deg, 0)) * (PI / 180.0))
	_basis = model_basis * _skel.transform.basis

	var tips := []
	for t in TIPS:
		tips.append(_skel.find_bone(t))
	var hips := _skel.find_bone("Hips")

	# Floor offset, matching AnimatedFighterRig._reground_to_pose(): the model is grounded ONCE
	# from the idle pose, so every other clip shares that same offset.
	var rest_low := INF
	var idle_low := INF
	for b in ch.rig.foot_bones:
		var bi := _skel.find_bone(b)
		if bi >= 0:
			rest_low = minf(rest_low, _pos(bi, true).y)
	ap.play("kb/" + String(ch.rig.state_clips["idle"]))
	ap.seek(0.0, true)
	for b in ch.rig.foot_bones:
		var bi := _skel.find_bone(b)
		if bi >= 0:
			idle_low = minf(idle_low, _pos(bi, false).y)
	var floor_off: float = rest_low - idle_low

	var misses := 0
	print("move            clip                        act  tip        tipY(active)  boxY         tipX(active)  boxX")
	for m in ch.moves.values():
		if m.projectile:
			print("%-15s (projectile - box is the shot, not a limb)" % m.id)
			continue
		var clip: String = m.anim_clip if m.anim_clip != "" else ch.rig.default_move_clip
		var full := "kb/" + clip
		if not ap.has_animation(full):
			print("%-15s %-27s MISSING CLIP" % [m.id, clip])
			continue
		var clip_len: float = ap.get_animation(full).length
		var frac := float(ch.rig.clip_impacts.get(clip, 0.0))
		var timing := AnimatedFighterRig.attack_timing(clip_len, frac, m.startup)
		ap.play(full)

		# Striking limb = the one that has travelled furthest from its start (relative to the
		# hips, so a step forward does not win) by the first active frame. Same rule probe_impact
		# uses to locate the impact.
		ap.seek(0.0, true)
		var h0: Vector3 = _pos(hips, false)
		var start := []
		for j in range(tips.size()):
			start.append(_pos(tips[j], false) - h0)
		ap.seek(_clip_time(timing, m.startup, clip_len), true)
		var h: Vector3 = _pos(hips, false)
		var tip := 0
		var best := -INF
		for j in range(tips.size()):
			# A kick's free arm swings as far as the leg does, so let the clip name pick the pair
			# of limbs that can be the strike (same rule as probe_impact.gd).
			if ("Kick" in clip) != (j >= 2):
				continue
			var travel: float = ((_pos(tips[j], false) - h) - start[j]).length()
			if travel > best:
				best = travel
				tip = j

		# Sweep the whole active window: long multi-hit moves keep swinging while the box stays put.
		var y_lo := INF
		var y_hi := -INF
		var x_lo := INF
		var x_hi := -INF
		for f in range(m.startup, m.startup + m.active):
			ap.seek(_clip_time(timing, f, clip_len), true)
			var p: Vector3 = _pos(tips[tip], false)
			y_lo = minf(y_lo, p.y + floor_off)
			y_hi = maxf(y_hi, p.y + floor_off)
			x_lo = minf(x_lo, absf(p.x))
			x_hi = maxf(x_hi, absf(p.x))
		var by_lo: float = m.hit_offset.y - m.hit_size.y * 0.5
		var by_hi: float = m.hit_offset.y + m.hit_size.y * 0.5
		var bx_lo: float = m.hit_offset.x - m.hit_size.x * 0.5
		var bx_hi: float = m.hit_offset.x + m.hit_size.x * 0.5
		# Miss = the limb is never inside the box vertically at any point of the active window.
		# Air normals are exempt: a jump-in box deliberately hangs at the fighter's feet so it
		# reaches a grounded opponent on the way down (see run_tests.gd::_test_jump_in), which
		# puts it below the reused grounded mocap limb by design.
		var miss: bool = (y_hi < by_lo or y_lo > by_hi) and m.stance != GameConst.Stance.AIR
		if miss:
			misses += 1
		print("%-15s %-27s %3d  %-10s %4.2f..%4.2f  %4.2f..%4.2f  %4.2f..%4.2f  %4.2f..%4.2f%s" % [
			m.id, clip, m.active, TIPS[tip], y_lo, y_hi, by_lo, by_hi, x_lo, x_hi, bx_lo, bx_hi,
			"  <== MISS" if miss else ("  (air: box hangs low by design)" if m.stance == GameConst.Stance.AIR else "")])
	print("\n%d move(s) with the hitbox outside the striking limb." % misses)
	quit()

func _clip_time(timing: Vector2, state_frame: int, clip_len: float) -> float:
	return clampf(timing.y + timing.x * float(state_frame) / GameConst.TICK_RATE, 0.0, clip_len)

## Godot's get_bone_global_pose() does not refresh while an AnimationPlayer is seeked from a
## headless SceneTree, so walk the parent chain by hand, then apply the model+skeleton basis
## (a pure Y rotation here, so it only matters for the forward axis).
func _pos(idx: int, rest: bool) -> Vector3:
	var t := Transform3D()
	var i := idx
	while i >= 0:
		t = (_skel.get_bone_rest(i) if rest else _skel.get_bone_pose(i)) * t
		i = _skel.get_bone_parent(i)
	return _basis * t.origin

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null
