from __future__ import annotations

from copy import deepcopy
import importlib.util
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


def _export_roundtrip(source: Path, destination: Path) -> None:
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
        bpy.ops.object.select_all(action="DESELECT")
        for obj in imported:
            obj.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=str(destination),
            use_selection=True,
            object_types={"ARMATURE", "MESH"},
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

    with tempfile.TemporaryDirectory() as temp_dir:
        candidate_path = Path(temp_dir) / "maskman_roundtrip.fbx"
        _export_roundtrip(REFERENCE_PATH, candidate_path)
        reference = validator.load_snapshot(REFERENCE_PATH)
        candidate = validator.load_snapshot(candidate_path)

    assert not validator.compare_armatures(reference, candidate, 1e-6)["passed"]
    assert validator.compare_armatures(reference, candidate, 2e-5)["passed"]

    changed = deepcopy(candidate)
    changed["bones"]["LeftArm"]["world_matrix"][3] += 1e-3
    assert not validator.compare_armatures(reference, changed, 2e-5)["passed"]

    clean = _clean_candidate_snapshot()
    assert validator.check_candidate(clean)["passed"]

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
