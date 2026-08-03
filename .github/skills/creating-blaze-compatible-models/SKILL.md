---
name: creating-blaze-compatible-models
description: Use when character images or an FBX in AssetsSource must be rigged, reskinned, or converted for Blaze's Maskman skeleton and Kubold KB_*.fbx animations.
---

# Creating Blaze-Compatible Models

## Contract

Accept one or more views of one character, or one `.fbx`. Produce one final `.fbx`.

The compatibility authority is the immutable armature in `characters\blaze\assets\maskman.fbx`, resolved from this skill's repository rather than `AssetsSource`. Matching names, auto-rigs, and `KB_*.fbx` files cannot replace it. If Maskman is unavailable, return `unverified`.

## Input Branches

| Input | Keep | Replace or create |
|---|---|---|
| Images | Identity, clothing, colors, silhouette from every view | Generate an unrigged mesh and textures |
| FBX | Character mesh, materials, textures | Discard its rig and animations |

For images, generate only the character:

```text
Create one unrigged, game-ready humanoid from all supplied views. Preserve identity, clothing, colors, and silhouette. Use a neutral T-pose, clean joint topology, separated fingers, manifold geometry, no base, animation, or skeleton. Limit to 30,000 triangles and one 1024px PBR texture set.
```

## Workflow

1. Confirm the input and canonical Maskman FBXs exist.
2. Import the character and Maskman into Blender. Duplicate Maskman's armature.
3. Fit only the character mesh to Maskman's bind pose. Never edit, rename, reparent, move, rotate, scale, or reroll its bones or armature object.
4. Bind every mesh to that armature. Normalize every vertex to one through four bone influences; correct shoulders, hips, fingers, hair, and loose clothing.
5. Export only the character meshes and armature as one FBX with no baked animation or leaf bones.
6. Run the bundled validator instead of writing a new one:

```powershell
blender --background --python "<skill-dir>\scripts\validate_blaze_fbx.py" -- --candidate "<output.fbx>"
```

When only Blender MCP is available, load `scripts\validate_blaze_fbx.py` in Blender Python and call `validate_files(default_reference_path(), candidate_path)`.

The validator requires exact bone count, order, names, and parents; checks world-space rest data at its FBX-round-trip-calibrated default `2e-5`; rejects animation; and rejects missing, unnormalized, or fifth-plus vertex influences. `--tolerance` calibrates serialization only; it cannot excuse a visibly different rig.

7. Visually play idle, movement, crouch, jump, attack, hit, knockdown, and get-up clips. Inspect shoulders, hips, fingers, hair, feet, and loose clothing.

## Verdict

| Machine validator | Visual clip test | Verdict |
|---|---|---|
| Pass | Pass | `exact` |
| Pass or fail | Missing or fail | `unverified` |
| Fail | Any result | `unverified` |

Headless or numeric checks do not prove deformation.

## Output

When Blender tools exist, perform the conversion rather than returning instructions. Return the final FBX path and absolute path, `exact` or `unverified`, the validator summary, and the visual clips inspected or the precise missing evidence.

## Common Mistakes

| Mistake | Correction |
|---|---|
| Recreate the validator per task | Run the bundled script. |
| Treat matching names as compatibility | Order, parents, rest data, object transform, and skinning also matter. |
| Call a machine pass `exact` | Visual animation deformation is the second required gate. |
