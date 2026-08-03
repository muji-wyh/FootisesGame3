from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys


# ponytail: one calibrated tolerance is enough; split units only if real exports require it.
DEFAULT_TOLERANCE = 2e-5
WEIGHT_TOLERANCE = 1e-4
NONZERO_WEIGHT = 1e-8
REQUIRED_BONES = (
    "Root",
    "Hips",
    "LeftFoot",
    "RightFoot",
    "LeftToeBase",
    "RightToeBase",
)
DATA_BLOCKS = (
    "objects",
    "meshes",
    "armatures",
    "actions",
    "materials",
    "textures",
    "images",
    "collections",
    "cameras",
    "lights",
    "curves",
)


def default_reference_path() -> Path:
    return (
        Path(__file__).resolve().parents[4]
        / "characters"
        / "blaze"
        / "assets"
        / "maskman.fbx"
    )


def _flatten_matrix(matrix) -> list[float]:
    return [float(value) for row in matrix for value in row]


def _flatten_axes(matrix) -> list[float]:
    basis = matrix.to_3x3().normalized()
    return [
        float(value)
        for column in range(3)
        for value in basis.col[column]
    ]


def _max_delta(left: list[float], right: list[float]) -> float:
    if len(left) != len(right):
        return math.inf
    return max((abs(a - b) for a, b in zip(left, right)), default=0.0)


def _angle_delta(left: float, right: float) -> float:
    return abs((left - right + math.pi) % (2.0 * math.pi) - math.pi)


def _check(name: str, passed: bool, detail=None) -> dict:
    result = {"name": name, "passed": passed}
    if detail is not None:
        result["detail"] = detail
    return result


def _restore_blender_state(active_object, selected_objects, mode: str, frame: int) -> None:
    import bpy

    bpy.context.scene.frame_set(frame)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in selected_objects:
        if obj.name in bpy.data.objects:
            obj.select_set(True)
    if active_object is not None and active_object.name in bpy.data.objects:
        bpy.context.view_layer.objects.active = active_object
        if mode != "OBJECT":
            bpy.ops.object.mode_set(mode=mode)


def _remove_imported_data(collections: dict, before: dict) -> None:
    for name in DATA_BLOCKS:
        items = collections[name]
        for item in list(items):
            if item.as_pointer() not in before[name]:
                try:
                    items.remove(item, do_unlink=True)
                except TypeError:
                    items.remove(item)


def load_snapshot(path: Path) -> dict:
    import bpy

    path = Path(path).resolve()
    if not path.is_file():
        raise FileNotFoundError(f"FBX not found: {path}")

    collections = {name: getattr(bpy.data, name) for name in DATA_BLOCKS}
    before = {
        name: {item.as_pointer() for item in items}
        for name, items in collections.items()
    }
    active_object = bpy.context.view_layer.objects.active
    selected_objects = list(bpy.context.selected_objects)
    original_mode = active_object.mode if active_object is not None else "OBJECT"
    original_frame = bpy.context.scene.frame_current

    if active_object is not None and original_mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    try:
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.import_scene.fbx(
            filepath=str(path),
            use_anim=True,
            automatic_bone_orientation=False,
            use_prepost_rot=True,
            use_image_search=False,
            ignore_leaf_bones=False,
            force_connect_children=False,
        )
        imported = [
            obj for obj in bpy.data.objects
            if obj.as_pointer() not in before["objects"]
        ]
        armatures = [obj for obj in imported if obj.type == "ARMATURE"]
        meshes = [obj for obj in imported if obj.type == "MESH"]
        new_actions = sorted(
            action.name for action in bpy.data.actions
            if action.as_pointer() not in before["actions"]
        )

        snapshot = {
            "path": str(path),
            "armature_count": len(armatures),
            "armature_name": None,
            "armature_matrix": [],
            "bone_order": [],
            "bones": {},
            "actions": new_actions,
            "nla_actions": [],
            "meshes": [],
        }
        if len(armatures) != 1:
            return snapshot

        armature = armatures[0]
        bone_names = {bone.name for bone in armature.data.bones}
        bpy.ops.object.select_all(action="DESELECT")
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        rolls = {
            bone.name: float(bone.roll)
            for bone in armature.data.edit_bones
        }
        bpy.ops.object.mode_set(mode="OBJECT")

        nla_actions = []
        if armature.animation_data is not None:
            for track in armature.animation_data.nla_tracks:
                for strip in track.strips:
                    if strip.action is not None:
                        nla_actions.append(strip.action.name)

        snapshot.update({
            "armature_name": armature.name,
            "armature_matrix": _flatten_matrix(armature.matrix_world),
            "bone_order": [bone.name for bone in armature.data.bones],
            "actions": new_actions,
            "nla_actions": sorted(set(nla_actions)),
        })

        for bone in armature.data.bones:
            world_matrix = armature.matrix_world @ bone.matrix_local
            world_head = armature.matrix_world @ bone.head_local
            world_tail = armature.matrix_world @ bone.tail_local
            snapshot["bones"][bone.name] = {
                "parent": bone.parent.name if bone.parent else None,
                "world_matrix": _flatten_matrix(world_matrix),
                "axes": _flatten_axes(world_matrix),
                "world_length": float((world_tail - world_head).length),
                "roll": rolls[bone.name],
            }

        for mesh in meshes:
            armature_targets = [
                modifier.object.name if modifier.object is not None else None
                for modifier in mesh.modifiers
                if modifier.type == "ARMATURE"
            ]
            bone_groups = {
                group.index for group in mesh.vertex_groups
                if group.name in bone_names
            }
            vertices = []
            for vertex in mesh.data.vertices:
                weights = [
                    float(group.weight)
                    for group in vertex.groups
                    if group.group in bone_groups and group.weight > NONZERO_WEIGHT
                ]
                vertices.append({"index": vertex.index, "weights": weights})
            snapshot["meshes"].append({
                "name": mesh.name,
                "armature_targets": armature_targets,
                "vertices": vertices,
            })

        return snapshot
    finally:
        if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        _remove_imported_data(collections, before)
        _restore_blender_state(
            active_object,
            selected_objects,
            original_mode,
            original_frame,
        )


def compare_armatures(reference: dict, candidate: dict, tolerance: float) -> dict:
    checks = []
    checks.append(_check(
        "one_reference_armature",
        reference["armature_count"] == 1,
        {"count": reference["armature_count"]},
    ))
    checks.append(_check(
        "one_candidate_armature",
        candidate["armature_count"] == 1,
        {"count": candidate["armature_count"]},
    ))
    if reference["armature_count"] != 1 or candidate["armature_count"] != 1:
        return {"passed": False, "checks": checks}

    reference_order = reference["bone_order"]
    candidate_order = candidate["bone_order"]
    reference_names = set(reference_order)
    candidate_names = set(candidate_order)
    checks.extend([
        _check(
            "bone_count",
            len(reference_order) == len(candidate_order),
            {"reference": len(reference_order), "candidate": len(candidate_order)},
        ),
        _check(
            "bone_order",
            reference_order == candidate_order,
            {
                "reference": reference_order,
                "candidate": candidate_order,
            } if reference_order != candidate_order else None,
        ),
        _check(
            "bone_names",
            reference_names == candidate_names,
            {
                "missing": sorted(reference_names - candidate_names),
                "extra": sorted(candidate_names - reference_names),
            },
        ),
        _check(
            "required_bones",
            set(REQUIRED_BONES).issubset(candidate_names),
            {"missing": sorted(set(REQUIRED_BONES) - candidate_names)},
        ),
    ])

    parent_errors = []
    for name in sorted(reference_names & candidate_names):
        reference_parent = reference["bones"][name]["parent"]
        candidate_parent = candidate["bones"][name]["parent"]
        if reference_parent != candidate_parent:
            parent_errors.append({
                "bone": name,
                "reference": reference_parent,
                "candidate": candidate_parent,
            })
    checks.append(_check(
        "bone_parents",
        not parent_errors,
        {"count": len(parent_errors), "examples": parent_errors[:20]},
    ))

    object_delta = _max_delta(
        reference["armature_matrix"],
        candidate["armature_matrix"],
    )
    max_deltas = {
        "armature_matrix": object_delta,
        "world_rest_matrix": 0.0,
        "axes": 0.0,
        "world_length": 0.0,
        "roll": 0.0,
    }
    numeric_errors = []
    for name in sorted(reference_names & candidate_names):
        reference_bone = reference["bones"][name]
        candidate_bone = candidate["bones"][name]
        deltas = {
            "world_rest_matrix": _max_delta(
                reference_bone["world_matrix"],
                candidate_bone["world_matrix"],
            ),
            "axes": _max_delta(
                reference_bone["axes"],
                candidate_bone["axes"],
            ),
            "world_length": abs(
                reference_bone["world_length"] - candidate_bone["world_length"]
            ),
            "roll": _angle_delta(
                reference_bone["roll"],
                candidate_bone["roll"],
            ),
        }
        for check_name, delta in deltas.items():
            max_deltas[check_name] = max(max_deltas[check_name], delta)
            if delta > tolerance:
                numeric_errors.append({
                    "bone": name,
                    "check": check_name,
                    "delta": delta,
                })

    if object_delta > tolerance:
        numeric_errors.insert(0, {
            "bone": None,
            "check": "armature_matrix",
            "delta": object_delta,
        })
    checks.append(_check(
        "numeric_rest_data",
        not numeric_errors,
        {
            "tolerance": tolerance,
            "max_deltas": max_deltas,
            "failure_count": len(numeric_errors),
            "examples": numeric_errors[:20],
        },
    ))

    return {
        "passed": all(check["passed"] for check in checks),
        "checks": checks,
    }


def check_candidate(candidate: dict) -> dict:
    checks = []
    armature_name = candidate.get("armature_name")
    checks.append(_check(
        "one_armature",
        candidate["armature_count"] == 1,
        {"count": candidate["armature_count"]},
    ))
    checks.append(_check(
        "no_animation",
        not candidate["actions"] and not candidate["nla_actions"],
        {
            "actions": candidate["actions"],
            "nla_actions": candidate["nla_actions"],
        },
    ))
    checks.append(_check(
        "has_mesh",
        bool(candidate["meshes"]),
        {"count": len(candidate["meshes"])},
    ))

    modifier_errors = []
    weight_errors = []
    vertex_count = 0
    for mesh in candidate["meshes"]:
        if mesh["armature_targets"] != [armature_name]:
            modifier_errors.append({
                "mesh": mesh["name"],
                "targets": mesh["armature_targets"],
                "expected": [armature_name],
            })
        vertex_count += len(mesh["vertices"])
        for vertex in mesh["vertices"]:
            weights = vertex["weights"]
            if not 1 <= len(weights) <= 4:
                weight_errors.append({
                    "mesh": mesh["name"],
                    "vertex": vertex["index"],
                    "issue": "influence_count",
                    "count": len(weights),
                })
                continue
            weight_sum = sum(weights)
            if abs(weight_sum - 1.0) > WEIGHT_TOLERANCE:
                weight_errors.append({
                    "mesh": mesh["name"],
                    "vertex": vertex["index"],
                    "issue": "weight_sum",
                    "sum": weight_sum,
                })

    checks.extend([
        _check(
            "mesh_armature_modifiers",
            not modifier_errors,
            {
                "failure_count": len(modifier_errors),
                "examples": modifier_errors[:20],
            },
        ),
        _check(
            "has_vertices",
            vertex_count > 0,
            {"count": vertex_count},
        ),
        _check(
            "normalized_max_four_weights",
            not weight_errors,
            {
                "failure_count": len(weight_errors),
                "examples": weight_errors[:20],
            },
        ),
    ])
    return {
        "passed": all(check["passed"] for check in checks),
        "checks": checks,
    }


def validate_files(
    reference_path: Path,
    candidate_path: Path,
    tolerance: float = DEFAULT_TOLERANCE,
) -> dict:
    if tolerance <= 0:
        raise ValueError("tolerance must be greater than zero")

    reference_path = Path(reference_path).resolve()
    candidate_path = Path(candidate_path).resolve()
    reference = load_snapshot(reference_path)
    candidate = load_snapshot(candidate_path)
    armature = compare_armatures(reference, candidate, tolerance)
    candidate_checks = check_candidate(candidate)
    passed = armature["passed"] and candidate_checks["passed"]
    return {
        "passed": passed,
        "machine_validation": "passed" if passed else "failed",
        "reference": str(reference_path),
        "candidate": str(candidate_path),
        "tolerance": tolerance,
        "armature": armature,
        "candidate_checks": candidate_checks,
        "exact_requires_visual_validation": True,
    }


def _user_args(argv: list[str]) -> list[str]:
    if "--" in argv:
        return argv[argv.index("--") + 1:]
    return argv[1:]


def _parse_args(argv: list[str]):
    parser = argparse.ArgumentParser(
        description="Validate a candidate FBX against Blaze's Maskman armature.",
    )
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--reference", type=Path, default=default_reference_path())
    parser.add_argument("--tolerance", type=float, default=DEFAULT_TOLERANCE)
    return parser.parse_args(_user_args(argv))


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(sys.argv if argv is None else argv)
    try:
        report = validate_files(args.reference, args.candidate, args.tolerance)
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        print(json.dumps({"passed": False, "error": str(error)}, indent=2))
        return 2
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
