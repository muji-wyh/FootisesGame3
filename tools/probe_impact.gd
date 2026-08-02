extends SceneTree
## Measures where the strike lands inside each of a character's attack clips, as a fraction of the
## clip's length, and prints them ready to paste into RigConfig.clip_impacts. The Kubold clips are
## real-time mocap, so the strike is nowhere near the middle -- most land at 0.17-0.3 and the rest
## of the clip is the settle back to guard. AnimatedFighterRig needs those fractions to line the
## strike up with the move's first active frame; without them it squeezes the whole clip into the
## move and the attack plays back 2-4x too fast.
##
##   godot4.7 --headless --path . --script res://tools/probe_impact.gd -- blaze
##
## Re-run this when a character's attack clips change; do not hand-tune the numbers.

const TIPS := ["RightHand", "LeftHand", "RightFoot", "LeftFoot"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var ch := CharacterLibrary.create(args[0] if args.size() > 0 else "blaze")
	var model := (load(ch.model_path) as PackedScene).instantiate() as Node3D
	var ap := _find(model, "AnimationPlayer") as AnimationPlayer
	var skel := _find(model, "Skeleton3D") as Skeleton3D
	ap.add_animation_library("kb", AnimatedFighterRig.build_library(ch.rig))
	root.add_child(model)
	ap.clear_caches()
	var hips := skel.find_bone("Hips")
	var tips := []
	for t in TIPS:
		tips.append(skel.find_bone(t))
	var seen := {}
	print("move            clip                          len   peak_t  frac  tip")
	for m in ch.moves.values():
		var clip: String = m.anim_clip if m.anim_clip != "" else ch.rig.default_move_clip
		var full := "kb/" + clip
		if not ap.has_animation(full):
			continue
		var len: float = ap.get_animation(full).length
		ap.play(full)
		var n := int(len * 30.0)
		# The striking limb is the one that travels furthest from where it started, and the impact
		# is where it gets there. Measuring each tip against its OWN start ignores a planted foot,
		# which otherwise wins on raw reach without ever being the thing that hits. Tracking
		# relative to the hips ignores the whole body stepping forward for the same reason.
		ap.seek(0.0, true)
		var origin: Array = []
		var h0: Vector3 = _fk(skel, hips).origin
		for j in range(tips.size()):
			origin.append(_fk(skel, tips[j]).origin - h0)
		var best := 0.0
		var best_t := 0.0
		var best_tip := ""
		for i in range(n + 1):
			var t := len * float(i) / float(n)
			ap.seek(t, true)
			var h: Vector3 = _fk(skel, hips).origin
			for j in range(tips.size()):
				# A kick's free arm swings as far as the leg does, so let the clip name pick the
				# pair of limbs that can be the strike.
				if ("Kick" in clip) != (j >= 2):
					continue
				var travel: float = ((_fk(skel, tips[j]).origin - h) - origin[j]).length()
				if travel > best:
					best = travel
					best_t = t
					best_tip = TIPS[j]
		seen[clip] = snappedf(best_t / len, 0.01)
		print("%-15s %-28s %5.2f %7.2f %5.2f  %s" % [m.id, clip, len, best_t, best_t / len, best_tip])
	print("\nclip_impacts = ", JSON.stringify(seen, "\t"))
	quit()

## Godot's get_bone_global_pose() does not refresh while an AnimationPlayer is being seeked from a
## headless SceneTree -- every sample comes back identical -- so walk the parent chain by hand.
func _fk(skel: Skeleton3D, idx: int) -> Transform3D:
	var t := Transform3D()
	var i := idx
	while i >= 0:
		t = skel.get_bone_pose(i) * t
		i = skel.get_bone_parent(i)
	return t

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null
