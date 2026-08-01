# Gallery Assets Directory Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move shared licensed gallery packs from `characters/` to `assets/third_party/` without changing gallery or combat behavior.

**Architecture:** Keep playable-character assets under `characters/<id>/assets`, but place shared third-party packs under `assets/third_party/<pack>/`. Gallery scenes and scripts remain in the existing UI layers; only their resource roots change.

**Tech Stack:** Godot 4.7, typed GDScript, `.tscn` resources, PowerShell, existing headless test harness

## Global Constraints

- Preserve `characters/blaze/assets/`; it is owned by Blaze's `CharacterData` and `RigConfig`.
- Preserve all current gallery behavior and gameplay hit-effect routing.
- Keep licensed binaries and generated `.import` files ignored while tracking each pack's `README.md`.
- Preserve pre-existing uncommitted edits in `scripts/match/MatchScene.gd` and `tools/run_tests.gd`; do not commit those files as part of this cleanup.
- Use Windows paths for filesystem commands and Godot `res://` paths inside project resources.

---

## File Map

- Move: `characters/animation_gallery2/assets/` → `assets/third_party/hit_reaction_animation/`
- Move: `characters/fighter_animation_gallery/assets/` → `assets/third_party/fighter_animation_pack/`
- Move: `characters/vfx_gallery/assets/` → `assets/third_party/vfx_impact_and_hit/`
- Modify: `.gitignore` — ignore licensed files at their new roots
- Modify: `scripts/ui/AnimationGallery2.gd` — default hit-reaction pack paths
- Modify: `scenes/ui/GALLERY-FighterAnimationPack.tscn` — Fighter Animation Pack paths
- Modify: `scripts/ui/VFXGallery.gd` — VFX gallery root
- Modify: `scripts/match/MatchScene.gd` — gameplay VFX root
- Modify: `tools/run_tests.gd` — expected resource roots
- Modify: moved pack `README.md` files — installation paths
- Modify locally: `assets/third_party/vfx_impact_and_hit/effects/**/*.tscn` — internal texture/model paths

### Task 1: Lock the New Resource Roots in Tests

**Files:**
- Modify: `tools/run_tests.gd:938-1023`
- Modify: `tools/run_tests.gd:1725`

**Interfaces:**
- Consumes: Existing `_paths_from_files()` helpers and `ResourceLoader.exists()`
- Produces: Assertions for the three new `assets/third_party/` roots

- [ ] **Step 1: Change only the expected paths**

In `_test_animation_gallery2()`, replace:

```gdscript
"res://characters/animation_gallery2/assets/anims/UE4M_HitReaction_Back_01.fbx",
"res://characters/animation_gallery2/assets/anims/UE4M_HitReaction_Front_01.fbx",
```

with:

```gdscript
"res://assets/third_party/hit_reaction_animation/anims/UE4M_HitReaction_Back_01.fbx",
"res://assets/third_party/hit_reaction_animation/anims/UE4M_HitReaction_Front_01.fbx",
```

In `_test_vfx_gallery()`, use:

```gdscript
var effect_root := "res://assets/third_party/vfx_impact_and_hit/effects"
```

for the `_paths_from_files()` input and expected `VFX_A.tscn` / `VFX_B.tscn` paths.

In `_test_impact_fx_smoke()`, replace the VFX root with:

```gdscript
var vfx_root := "res://assets/third_party/vfx_impact_and_hit/effects/impact_1_1_0/"
```

- [ ] **Step 2: Run the harness and confirm the path assertions fail**

Run:

```powershell
& C:\uworks\tools\Godot_v4.7-stable_win64_console.exe --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd
```

Expected: failure in the Gallery2 and/or VFX gallery path expectations because production paths still point at `characters/`.

- [ ] **Step 3: Do not commit the test file**

`tools/run_tests.gd` already contains uncommitted user work for gameplay VFX routing. Leave it unstaged so this cleanup does not claim ownership of that work.

### Task 2: Move the Animation Gallery Packs

**Files:**
- Move: `characters/animation_gallery2/assets/README.md`
- Move: `characters/fighter_animation_gallery/assets/README.md`
- Modify: `.gitignore:29-42`
- Modify: `scripts/ui/AnimationGallery2.gd:4-6`
- Modify: `scenes/ui/GALLERY-FighterAnimationPack.tscn:8-10`

**Interfaces:**
- Consumes: `AnimationGallery2` exported `display_model_path`, `animation_dir`, and `texture_dir`
- Produces: Identical gallery loading from `assets/third_party/hit_reaction_animation` and `assets/third_party/fighter_animation_pack`

- [ ] **Step 1: Move both local pack directories**

Run:

```powershell
New-Item -ItemType Directory -Force assets\third_party | Out-Null
Move-Item characters\animation_gallery2\assets assets\third_party\hit_reaction_animation
Move-Item characters\fighter_animation_gallery\assets assets\third_party\fighter_animation_pack
Remove-Item characters\animation_gallery2
Remove-Item characters\fighter_animation_gallery
```

Expected: models, animations, textures, and tracked READMEs now exist under `assets\third_party\`.

- [ ] **Step 2: Update the shared animation gallery defaults**

Set these exports in `scripts/ui/AnimationGallery2.gd`:

```gdscript
@export_file("*.fbx") var display_model_path := "res://assets/third_party/hit_reaction_animation/model.fbx"
@export_dir var animation_dir := "res://assets/third_party/hit_reaction_animation/anims"
@export_dir var texture_dir := "res://assets/third_party/hit_reaction_animation/tex/"
```

- [ ] **Step 3: Update the Fighter Animation Pack scene overrides**

Set these values in `scenes/ui/GALLERY-FighterAnimationPack.tscn`:

```text
display_model_path = "res://assets/third_party/fighter_animation_pack/model.fbx"
animation_dir = "res://assets/third_party/fighter_animation_pack/anims"
texture_dir = "res://assets/third_party/fighter_animation_pack/tex/"
```

- [ ] **Step 4: Extend the licensed-resource ignore rules**

Keep the existing `characters/**/assets/**` rules for Blaze and add:

```gitignore
assets/third_party/**/*.fbx
assets/third_party/**/*.FBX
assets/third_party/**/*.tga
assets/third_party/**/*.png
assets/third_party/**/*.tscn
assets/third_party/**/*.fbx.import
assets/third_party/**/*.FBX.import
assets/third_party/**/*.tga.import
assets/third_party/**/*.png.import
assets/third_party/**/*.tscn.import
```

Do not ignore `*.md`, so the moved READMEs remain tracked.

- [ ] **Step 5: Update the two moved READMEs**

Document these exact installation roots:

```text
assets/third_party/hit_reaction_animation/
assets/third_party/fighter_animation_pack/
```

Retain the source-pack and clip-count notes already present.

- [ ] **Step 6: Commit the isolated animation-pack move**

Run:

```powershell
git add .gitignore scripts\ui\AnimationGallery2.gd scenes\ui\GALLERY-FighterAnimationPack.tscn characters\animation_gallery2\assets\README.md characters\fighter_animation_gallery\assets\README.md assets\third_party\hit_reaction_animation\README.md assets\third_party\fighter_animation_pack\README.md
git commit -m "Move gallery animation packs out of characters" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: Git records the README moves and path changes; ignored licensed binaries remain local.

### Task 3: Move the Shared VFX Pack

**Files:**
- Move: `characters/vfx_gallery/assets/README.md`
- Modify: `scripts/ui/VFXGallery.gd:3`
- Modify: `scripts/match/MatchScene.gd:24`
- Modify locally: `assets/third_party/vfx_impact_and_hit/effects/**/*.tscn`

**Interfaces:**
- Consumes: `VFXGallery.EFFECT_ROOT`, `MatchScene.HIT_VFX_ROOT`, and existing `HitSpark.setup()`
- Produces: Gallery enumeration and gameplay hit effects from one shared VFX pack root

- [ ] **Step 1: Move the local VFX pack**

Run:

```powershell
Move-Item characters\vfx_gallery\assets assets\third_party\vfx_impact_and_hit
Remove-Item characters\vfx_gallery
```

- [ ] **Step 2: Rewrite internal VFX resource references**

Run this bounded bulk replacement over the moved `.tscn` files:

```powershell
$files = Get-ChildItem assets\third_party\vfx_impact_and_hit\effects -Recurse -File -Filter *.tscn
foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $content = $content.Replace(
        "res://characters/vfx_gallery/assets/",
        "res://assets/third_party/vfx_impact_and_hit/"
    )
    Set-Content -LiteralPath $file.FullName -Value $content -NoNewline
}
```

Expected: searching the moved effects returns zero old roots:

```powershell
rg "res://characters/vfx_gallery" assets\third_party\vfx_impact_and_hit
```

- [ ] **Step 3: Update gallery and gameplay roots**

In `scripts/ui/VFXGallery.gd`:

```gdscript
const EFFECT_ROOT := "res://assets/third_party/vfx_impact_and_hit/effects"
```

In the existing uncommitted VFX block in `scripts/match/MatchScene.gd`:

```gdscript
const HIT_VFX_ROOT := "res://assets/third_party/vfx_impact_and_hit/effects/impact_1_1_0/"
```

Change only this string; preserve the surrounding user-authored routing logic.

- [ ] **Step 4: Update the moved VFX README**

State that `effects/`, `models/`, and `textures/` belong under:

```text
assets/third_party/vfx_impact_and_hit/
```

Keep the existing licensed source location and relocation note.

- [ ] **Step 5: Remove stale generated import sidecars**

Run:

```powershell
$imports = Get-ChildItem assets\third_party -Recurse -File -Filter *.import
foreach ($import in $imports) {
    Remove-Item -LiteralPath $import.FullName
}
```

Expected: only generated `.import` sidecars are removed; source FBX, PNG, and TSCN files remain.

- [ ] **Step 6: Commit only cleanly owned tracked files**

Run:

```powershell
git add scripts\ui\VFXGallery.gd characters\vfx_gallery\assets\README.md assets\third_party\vfx_impact_and_hit\README.md
git commit -m "Move shared VFX pack out of characters" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Leave `scripts/match/MatchScene.gd`, `tools/run_tests.gd`, and ignored VFX resources unstaged because they contain or derive from pre-existing local user work.

### Task 4: Reimport and Validate the Complete Migration

**Files:**
- Verify: `.gitignore`
- Verify: `scripts/ui/AnimationGallery2.gd`
- Verify: `scripts/ui/VFXGallery.gd`
- Verify: `scripts/match/MatchScene.gd`
- Verify: `scenes/ui/GALLERY-FighterAnimationPack.tscn`
- Verify: `tools/run_tests.gd`

**Interfaces:**
- Consumes: All new resource roots
- Produces: Imported Godot resources and passing gallery/combat regression checks

- [ ] **Step 1: Confirm no project references use the removed directories**

Run:

```powershell
rg "characters/(animation_gallery2|fighter_animation_gallery|vfx_gallery)" --glob "*.{gd,tscn,md,godot}" .
```

Expected: no matches.

- [ ] **Step 2: Refresh Godot imports**

Run:

```powershell
& C:\uworks\tools\Godot_v4.7-stable_win64_console.exe --headless --path C:\uworks\FootisesGame3 --import
```

Expected: exit code `0`, with no missing dependency errors under `assets/third_party/`.

- [ ] **Step 3: Run the full headless suite**

Run:

```powershell
& C:\uworks\tools\Godot_v4.7-stable_win64_console.exe --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd
```

Expected: all tests pass; installed local packs report 97 hit-reaction clips, 313 fighter animations, and 63 VFX scenes.

- [ ] **Step 4: Verify ignored assets and tracked documentation**

Run:

```powershell
git check-ignore assets\third_party\vfx_impact_and_hit\effects\impact_1_1_0\VFX_ImpactClassic01_1.1.0.tscn
git check-ignore assets\third_party\hit_reaction_animation\model.fbx
git check-ignore assets\third_party\fighter_animation_pack\tex\9CG.png
git ls-files assets\third_party\*\README.md
```

Expected: the first three commands print their paths; `git ls-files` prints all three READMEs.

- [ ] **Step 5: Review the final working tree**

Run:

```powershell
git --no-pager status --short
git --no-pager diff -- scripts\match\MatchScene.gd tools\run_tests.gd
```

Expected: no removed gallery directories remain. The two intentionally unstaged files contain the user's existing VFX work plus only the required root-string substitutions.
