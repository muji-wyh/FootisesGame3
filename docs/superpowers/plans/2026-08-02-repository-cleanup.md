# Repository Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove approved orphaned, completed, generated, and outdated files while preserving all runtime fallbacks and Godot resource metadata.

**Architecture:** First repair retained documentation so it no longer points at deleted workflows or machine-specific binaries. Then remove the approved tracked files as one deletion-only change, delete approved ignored outputs locally, and validate the surviving project from a fresh Godot import.

**Tech Stack:** Godot 4.7 via `godot4.7`, typed GDScript, Git, PowerShell, Markdown

## Global Constraints

- Delete only paths explicitly approved in the cleanup design.
- Keep `.godot/`, tracked `.uid` files, and tracked `.import` files.
- Keep `tools/gen_audio.py`, `tools/serve.py`, CartoonFX fallback assets, `FighterRig.gd`, and all Gallery runtime files.
- Preserve the pending `README.md` change that replaces hard-coded binaries with `godot4.7`.
- Delete `.superpowers/` and `web-build/` locally after tracked cleanup.
- Run Godot import and the complete headless suite with the `godot4.7` command from `PATH`.

---

### Task 1: Repair Retained Documentation

**Files:**
- Modify: `README.md:67-84`
- Modify: `.github/copilot-instructions.md:1-24,71`
- Modify: `docs/footsies-design.md:1-10,108-129`

**Interfaces:**
- Consumes: The environment-provided `godot4.7` executable
- Produces: Current contributor commands and a self-contained footsies design contract

- [ ] **Step 1: Confirm the stale documentation references exist**

Run:

```powershell
rg "Godot_v4\.7-stable|openspec|opsx|add-training-spacing-drills" README.md .github\copilot-instructions.md docs\footsies-design.md
```

Expected: hard-coded Godot binary paths in Copilot instructions and OpenSpec references in the retained docs.

- [ ] **Step 2: Replace the Copilot command block**

Use this command block in `.github/copilot-instructions.md`:

```powershell
# Run in the editor / desktop
godot4.7 --path C:\uworks\FootisesGame3

# Refresh Godot's global class cache after adding class_name scripts or importing assets
godot4.7 --headless --path C:\uworks\FootisesGame3 --import

# Run the full headless combat / round / AI suite
godot4.7 --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd

# Export the Web build
godot4.7 --headless --path C:\uworks\FootisesGame3 --export-release "Web" C:\uworks\FootisesGame3\web-build\index.html
```

Delete the final paragraph beginning `This repo has OpenSpec/Copilot workflow files`.

- [ ] **Step 3: Make the footsies document self-contained**

Replace:

```markdown
Treat this document as the reference contributors point at when proposing balance, system,
or training changes. Source of truth for the formal requirements is
`openspec/changes/refine-footsies-neutral-identity/specs/footsies-neutral/spec.md`.
```

with:

```markdown
Treat this document as the source of truth contributors use when proposing balance, system,
or training changes.
```

Delete the complete section from:

```markdown
### Proposed next change: `add-training-spacing-drills`
```

through its final `Non-goals` bullet, leaving `## 5. Targeted playtest checklist` as the next
section.

- [ ] **Step 4: Verify retained docs contain no stale references**

Run:

```powershell
rg "Godot_v4\.7-stable|openspec|opsx|add-training-spacing-drills" README.md .github\copilot-instructions.md docs\footsies-design.md
```

Expected: no matches.

- [ ] **Step 5: Commit the retained documentation updates**

Run:

```powershell
git add README.md .github\copilot-instructions.md docs\footsies-design.md
git commit -m "Refresh contributor documentation" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Delete Approved Tracked Orphans

**Files:**
- Delete: `.idea/`
- Delete: `.github/prompts/`
- Delete: `.github/skills/`
- Delete: `docs/superpowers/`
- Delete: `tools/gen_textures.py`
- Delete: `tools/inspect_models.gd`
- Delete: `tools/inspect_models.gd.uid`

**Interfaces:**
- Consumes: The explicit deletion whitelist from the approved cleanup design
- Produces: A tracked tree without IDE metadata, orphaned OpenSpec workflows, completed process docs, or stale one-off asset probes

- [ ] **Step 1: Confirm every deletion target is tracked**

Run:

```powershell
git ls-files .idea .github/prompts .github/skills docs/superpowers tools/gen_textures.py tools/inspect_models.gd tools/inspect_models.gd.uid
```

Expected: only files beneath the approved deletion paths.

- [ ] **Step 2: Delete only the approved tracked paths**

Run:

```powershell
git rm -r -- .idea .github/prompts .github/skills docs/superpowers
git rm -- tools/gen_textures.py tools/inspect_models.gd tools/inspect_models.gd.uid
```

- [ ] **Step 3: Verify protected files remain tracked**

Run:

```powershell
git ls-files tools/gen_audio.py tools/serve.py scripts/fighter/FighterRig.gd docs/footsies-design.md
git ls-files "assets/cartoon_fx_pack/*"
git ls-files "*.uid" "*.import"
```

Expected: every named protected file is printed, CartoonFX files remain, and Godot metadata
still has tracked entries.

- [ ] **Step 4: Verify deleted workflow/tool references are gone**

Run:

```powershell
rg "openspec|opsx|gen_textures|inspect_models|docs/superpowers" --glob "*.{md,gd,py,godot,yaml,yml}" .
```

Expected: no matches outside Git metadata or ignored local scratch that Task 3 will delete.

- [ ] **Step 5: Commit the tracked deletions**

Run:

```powershell
git commit -m "Remove obsolete repository files" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

The staged deletion already includes every approved tracked path; do not stage unrelated files.

### Task 3: Remove Generated Output and Validate

**Files:**
- Delete locally: `.superpowers/`
- Delete locally: `web-build/`
- Keep: `.godot/`

**Interfaces:**
- Consumes: The cleaned tracked tree from Tasks 1 and 2
- Produces: A clean local workspace and verified Godot project

- [ ] **Step 1: Inspect the two local deletion targets**

Run:

```powershell
Get-ChildItem -Force .superpowers,web-build
```

Expected: only ignored workflow scratch and generated Web export files.

- [ ] **Step 2: Delete the approved generated directories**

Run:

```powershell
Remove-Item -LiteralPath .superpowers -Recurse -Force
Remove-Item -LiteralPath web-build -Recurse -Force
```

Do not delete `.godot`.

- [ ] **Step 3: Confirm obsolete references and paths are absent**

Run:

```powershell
rg "openspec|opsx|gen_textures|inspect_models|docs/superpowers|Godot_v4\.7-stable" --glob "*.{md,gd,py,godot,yaml,yml}" .
git ls-files .idea .github/prompts .github/skills docs/superpowers tools/gen_textures.py tools/inspect_models.gd tools/inspect_models.gd.uid
```

Expected: both commands produce no matches.

- [ ] **Step 4: Refresh Godot imports**

Run:

```powershell
godot4.7 --headless --path C:\uworks\FootisesGame3 --import
```

Expected: exit code `0` with no missing-script or missing-resource errors.

- [ ] **Step 5: Run the complete test suite**

Run:

```powershell
godot4.7 --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd
```

Expected: all existing tests pass with `0 failed`.

- [ ] **Step 6: Review the final repository state**

Run:

```powershell
git --no-pager status --short
git --no-pager log -3 --oneline
```

Expected: no pending tracked changes; the latest commits are the documentation refresh and
obsolete-file deletion.
