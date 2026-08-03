# Blaze-Compatible Model Skill Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `creating-blaze-compatible-models` one portable Blender validator that produces reliable machine evidence without replacing required visual deformation checks.

**Architecture:** Keep model generation, fitting, and weight correction interactive. Put deterministic FBX import, armature comparison, animation rejection, and skin-weight checks in one bundled Python script; keep the skill body as the short orchestration contract.

**Tech Stack:** Blender Python (`bpy`), Python standard library, Markdown, JSON.

## Global Constraints

- Use no external Python packages.
- Resolve the default reference from the skill file location, not the working directory.
- Exact topology checks stay exact; numeric world-space checks default to `2e-5` and remain configurable.
- A passing script is necessary but not sufficient for `exact`; required animation clips must also be visually inspected.
- Do not automate input-dependent mesh fitting or deformation correction.

---

### Task 1: Add the Blender FBX Validator

**Files:**
- Create: `.github/skills/creating-blaze-compatible-models/scripts/validate_blaze_fbx.py`
- Create: `.github/skills/creating-blaze-compatible-models/scripts/test_validate_blaze_fbx.py`

**Interfaces:**
- Produces: `validate_files(reference_path: Path, candidate_path: Path, tolerance: float = 2e-5) -> dict`
- Produces: `load_snapshot(path: Path) -> dict`
- Produces: `compare_armatures(reference: dict, candidate: dict, tolerance: float) -> dict`
- Produces: `check_candidate(candidate: dict) -> dict`
- CLI: `blender --background --python validate_blaze_fbx.py -- --candidate <file> [--reference <file>] [--tolerance 0.00002]`

- [ ] **Step 1: Write the failing Blender regression check**

Create a test that:

```python
from copy import deepcopy

reference = load_snapshot(maskman_path)
roundtrip = export_and_load_roundtrip(maskman_path)
assert compare_armatures(reference, roundtrip, 2e-5)["passed"]

changed = deepcopy(roundtrip)
changed["bones"]["LeftArm"]["world_matrix"][3] += 1e-3
assert not compare_armatures(reference, changed, 2e-5)["passed"]

clean = minimal_candidate_snapshot()
assert check_candidate(clean)["passed"]

animated = deepcopy(clean)
animated["actions"] = ["Take 001"]
assert not check_candidate(animated)["passed"]

bad_weights = deepcopy(clean)
bad_weights["meshes"][0]["vertices"][0]["weights"] = [0.3, 0.3, 0.3, 0.3, 0.3]
assert not check_candidate(bad_weights)["passed"]
```

- [ ] **Step 2: Run the regression check and verify RED**

Run the test through Blender. Expected: import failure because `validate_blaze_fbx.py` and its functions do not exist.

- [ ] **Step 3: Implement the minimal validator**

Implement:

```python
DEFAULT_TOLERANCE = 2e-5
REQUIRED_BONES = (
    "Root", "Hips", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase",
)

def default_reference_path() -> Path:
    return Path(__file__).resolve().parents[4] / "characters" / "blaze" / "assets" / "maskman.fbx"

def validate_files(reference_path: Path, candidate_path: Path, tolerance: float = DEFAULT_TOLERANCE) -> dict:
    reference = load_snapshot(reference_path)
    candidate = load_snapshot(candidate_path)
    armature = compare_armatures(reference, candidate, tolerance)
    candidate_checks = check_candidate(candidate)
    return {
        "passed": armature["passed"] and candidate_checks["passed"],
        "reference": str(reference_path.resolve()),
        "candidate": str(candidate_path.resolve()),
        "tolerance": tolerance,
        "armature": armature,
        "candidate_checks": candidate_checks,
        "exact_requires_visual_validation": True,
    }
```

`load_snapshot()` must import into a temporary Blender scene, restore the caller's scene, and remove only data blocks created by the import. Snapshot actual edit-bone roll, world-space rest matrices and axes, exact order/names/parents, imported actions, armature modifiers, and per-vertex bone weights.

- [ ] **Step 4: Run the Blender regression check and verify GREEN**

Expected: unchanged Maskman round-trip passes armature comparison; deliberate rig, animation, and weight mutations fail.

- [ ] **Step 5: Commit the validator**

```powershell
git add .github\skills\creating-blaze-compatible-models\scripts
git commit -m "Add Blaze FBX compatibility validator" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Wire the Skill to the Validator

**Files:**
- Modify: `.github/skills/creating-blaze-compatible-models/SKILL.md`
- Modify: `.github/skills/creating-blaze-compatible-models/evals/evals.json`

**Interfaces:**
- Consumes: `scripts/validate_blaze_fbx.py`
- Produces: one concise workflow and output contract using validator JSON as machine evidence.

- [ ] **Step 1: Add failing eval expectations**

Add cases requiring:

```json
[
  "The canonical reference resolves from the skill repository rather than AssetsSource.",
  "The bundled validator is run instead of recreated.",
  "An unchanged Maskman FBX round trip passes at the calibrated tolerance.",
  "Any candidate animation, unweighted vertex, fifth influence, or changed bone fails.",
  "A passing machine report without visual clip playback remains unverified."
]
```

- [ ] **Step 2: Run the old skill evals and verify RED**

Expected: validator-generation eval remains incomplete and the old `1e-6` tolerance rejects the verified round trip.

- [ ] **Step 3: Replace validation prose with the executable contract**

Update the workflow to:

```text
Resolve Maskman from the skill repository, preserve its armature, export without animation, run scripts\validate_blaze_fbx.py, then visually inspect the required Kubold clips. Return exact only when both gates pass.
```

Keep the existing image/FBX branches and visual pressure guard. Remove the false `1e-6` claim and avoid adding provider-specific generation workflows.

- [ ] **Step 4: Run revised evals and package validation**

Run paired revised-skill and old-skill evals, aggregate the benchmark, generate the static review viewer, and run:

```powershell
$creator = "$env:USERPROFILE\.copilot\installed-plugins\anthropic-agent-skills\example-skills\skills\skill-creator"
python "$creator\scripts\quick_validate.py" .github\skills\creating-blaze-compatible-models
```

Expected: revised skill passes all targeted expectations and package validation succeeds.

- [ ] **Step 5: Commit the skill revision**

```powershell
git add .github\skills\creating-blaze-compatible-models
git commit -m "Improve Blaze-compatible model validation" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
