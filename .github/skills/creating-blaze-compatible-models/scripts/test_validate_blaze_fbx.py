"""Run with Blender's `--python-exit-code 1` so assertion failures fail the command."""

from __future__ import annotations

from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import tempfile

import bpy


SCRIPT_DIR = Path(__file__).resolve().parent
VALIDATOR_PATH = SCRIPT_DIR / "validate_blaze_fbx.py"
REFERENCE_PATH = Path(__file__).resolve().parents[4] / "characters" / "blaze" / "assets" / "maskman.fbx"
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


def _load_validator():
    spec = importlib.util.spec_from_file_location("validate_blaze_fbx", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {VALIDATOR_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _export_roundtrip(
    source: Path,
    destination: Path,
    armature_name: str | None = None,
    parent_name: str | None = None,
) -> None:
    collections = {name: getattr(bpy.data, name) for name in DATA_BLOCKS}
    before = {
        name: {item.as_pointer() for item in items}
        for name, items in collections.items()
    }
    original_scene = bpy.context.window.scene
    temp_scene = bpy.data.scenes.new("__blaze_validator_test__")
    bpy.context.window.scene = temp_scene

    try:
        bpy.ops.import_scene.fbx(
            filepath=str(source),
            use_anim=False,
            automatic_bone_orientation=False,
            use_prepost_rot=True,
        )
        imported = [
            obj for obj in bpy.data.objects
            if obj.as_pointer() not in before["objects"]
        ]
        armature = next(obj for obj in imported if obj.type == "ARMATURE")
        if armature_name is not None:
            armature.name = armature_name
        if parent_name is not None:
            parent = bpy.data.objects.new(parent_name, None)
            temp_scene.collection.objects.link(parent)
            armature.parent = parent
            imported.append(parent)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in imported:
            obj.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=str(destination),
            use_selection=True,
            object_types={"ARMATURE", "MESH", "EMPTY"},
            add_leaf_bones=False,
            bake_anim=False,
            axis_forward="-Z",
            axis_up="Y",
        )
    finally:
        bpy.context.window.scene = original_scene
        bpy.data.scenes.remove(temp_scene)
        for name in DATA_BLOCKS:
            items = collections[name]
            for item in list(items):
                if item.as_pointer() not in before[name]:
                    try:
                        items.remove(item, do_unlink=True)
                    except TypeError:
                        items.remove(item)


def _clean_candidate_snapshot() -> dict:
    return {
        "armature_count": 1,
        "armature_name": "Armature",
        "actions": [],
        "nla_actions": [],
        "meshes": [{
            "name": "Body",
            "armature_targets": ["Armature"],
            "vertices": [
                {"index": 0, "weights": [0.5, 0.5]},
                {"index": 1, "weights": [1.0]},
            ],
        }],
    }


def main() -> None:
    validator = _load_validator()
    assert REFERENCE_PATH.is_file(), f"Missing licensed reference: {REFERENCE_PATH}"

    scene = bpy.context.scene
    window = bpy.context.window
    original_view_layer = window.view_layer
    secondary_view_layer = scene.view_layers.new("__blaze_validator_test__")
    original_fps = scene.render.fps
    original_fps_base = scene.render.fps_base
    original_data_counts = {
        name: len(getattr(bpy.data, name))
        for name in validator.DATA_BLOCKS
    }
    try:
        window.view_layer = secondary_view_layer
        scene.render.fps = 13
        scene.render.fps_base = 1.25
        validator.load_snapshot(REFERENCE_PATH)
        assert window.view_layer == secondary_view_layer
        assert scene.render.fps == 13
        assert scene.render.fps_base == 1.25
        assert {
            name: len(getattr(bpy.data, name))
            for name in validator.DATA_BLOCKS
        } == original_data_counts
    finally:
        window.view_layer = original_view_layer
        scene.view_layers.remove(secondary_view_layer)
        scene.render.fps = original_fps
        scene.render.fps_base = original_fps_base

    with tempfile.TemporaryDirectory() as temp_dir:
        candidate_path = Path(temp_dir) / "maskman_roundtrip.fbx"
        renamed_path = Path(temp_dir) / "renamed_armature.fbx"
        reparented_path = Path(temp_dir) / "reparented_armature.fbx"
        colliding_name_path = Path(temp_dir) / "colliding_armature_name.fbx"
        _export_roundtrip(REFERENCE_PATH, candidate_path)
        _export_roundtrip(REFERENCE_PATH, renamed_path, armature_name="RenamedRig")
        _export_roundtrip(REFERENCE_PATH, reparented_path, parent_name="ExtraRoot")
        _export_roundtrip(
            REFERENCE_PATH,
            colliding_name_path,
            armature_name="Armature.001",
        )
        reference = validator.load_snapshot(REFERENCE_PATH)
        candidate = validator.load_snapshot(candidate_path)
        renamed_candidate = validator.load_snapshot(renamed_path)
        reparented_candidate = validator.load_snapshot(reparented_path)
        collision_objects = [
            bpy.data.objects.new("Armature", None),
            bpy.data.objects.new("Armature.001", None),
        ]
        try:
            for obj in collision_objects:
                scene.collection.objects.link(obj)
            collision_reference = validator.load_snapshot(REFERENCE_PATH)
            collision_candidate = validator.load_snapshot(colliding_name_path)
        finally:
            for obj in collision_objects:
                bpy.data.objects.remove(obj, do_unlink=True)

    assert not validator.compare_armatures(reference, candidate, 1e-6)["passed"]
    assert validator.compare_armatures(reference, candidate, 2e-5)["passed"]

    changed = deepcopy(candidate)
    changed["bones"]["LeftArm"]["world_matrix"][3] += 1e-3
    assert not validator.compare_armatures(reference, changed, 2e-5)["passed"]
    renamed_armature = deepcopy(candidate)
    renamed_armature["armature_name"] = "RenamedRig"
    assert not validator.compare_armatures(reference, renamed_armature, 2e-5)["passed"]
    assert not validator.compare_armatures(reference, renamed_candidate, 2e-5)["passed"]
    assert collision_reference["armature_name"] == "Armature"
    assert collision_candidate["armature_name"] == "Armature.001"
    assert not validator.compare_armatures(
        collision_reference,
        collision_candidate,
        2e-5,
    )["passed"]
    reference_with_path = deepcopy(reference)
    reference_with_path["armature_parent_path"] = []
    reparented_armature = deepcopy(candidate)
    reparented_armature["armature_parent_path"] = ["ExtraRoot"]
    assert not validator.compare_armatures(
        reference_with_path,
        reparented_armature,
        2e-5,
    )["passed"]
    assert not validator.compare_armatures(reference, reparented_candidate, 2e-5)["passed"]
    nonfinite_rest = deepcopy(candidate)
    nonfinite_rest["bones"]["LeftArm"]["world_matrix"][0] = float("nan")
    nonfinite_report = validator.compare_armatures(reference, nonfinite_rest, 2e-5)
    assert not nonfinite_report["passed"]
    json.dumps(nonfinite_report, allow_nan=False)
    for invalid_tolerance in (float("nan"), float("inf")):
        try:
            validator.compare_armatures(reference, changed, invalid_tolerance)
        except ValueError:
            pass
        else:
            raise AssertionError("Non-finite tolerance must be rejected")

    clean = _clean_candidate_snapshot()
    assert validator.check_candidate(clean)["passed"]

    nonfinite_weight = deepcopy(clean)
    nonfinite_weight["meshes"][0]["vertices"][0]["weights"] = [float("nan")]
    assert not validator.check_candidate(nonfinite_weight)["passed"]

    animated = deepcopy(clean)
    animated["actions"] = ["Take 001"]
    assert not validator.check_candidate(animated)["passed"]

    unweighted = deepcopy(clean)
    unweighted["meshes"][0]["vertices"][0]["weights"] = []
    assert not validator.check_candidate(unweighted)["passed"]

    fifth_influence = deepcopy(clean)
    fifth_influence["meshes"][0]["vertices"][0]["weights"] = [0.2] * 5
    assert not validator.check_candidate(fifth_influence)["passed"]

    bad_sum = deepcopy(clean)
    bad_sum["meshes"][0]["vertices"][0]["weights"] = [0.4, 0.4]
    assert not validator.check_candidate(bad_sum)["passed"]

    print("PASS: Blaze FBX validator regression")


if __name__ == "__main__":
    main()
