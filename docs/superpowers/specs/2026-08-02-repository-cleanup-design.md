# Repository Cleanup Design

## Goal

Remove files that are provably orphaned, completed, generated, or outdated without deleting
runtime fallbacks, reproducibility tools, or Godot metadata required by clean clones.

## Delete Tracked Files

- `.idea/`
- `.github/prompts/opsx-*.prompt.md`
- `.github/skills/openspec-*/`
- `docs/superpowers/`
- `tools/gen_textures.py`
- `tools/inspect_models.gd`
- `tools/inspect_models.gd.uid`

The OpenSpec workflow is orphaned because `openspec/config.yaml` and its active change files
were already removed. The migration design/plan documents describe completed work and are not
ongoing project documentation. The two development tools are one-off asset probes with stale
commands or paths and no repository callers.

## Update Retained Documentation

- `.github/copilot-instructions.md`
  - use `godot4.7` for editor, import, tests, and export
  - remove the obsolete OpenSpec workflow paragraph
- `docs/footsies-design.md`
  - make the document itself the source of truth
  - remove the deleted OpenSpec reference
  - remove the speculative `add-training-spacing-drills` change scaffold
- `README.md`
  - retain the pending `godot4.7` command update

## Delete Local Generated Output

- `.superpowers/`
- `web-build/`

Keep `.godot/` because it is the active Godot import cache and deleting it would force a large
reimport without reducing tracked repository complexity.

## Protected Files

Do not delete:

- `tools/gen_audio.py` or `tools/serve.py`
- `assets/cartoon_fx_pack/`, which is the clean-clone hit-effect fallback
- `scripts/fighter/FighterRig.gd`, which is the clean-clone character fallback
- Gallery scenes, scripts, or licensed local packs
- tracked `.uid` and `.import` files used by Godot resource identity/import settings
- `docs/footsies-design.md`, which remains the gameplay design contract

## Validation

1. Search for remaining `openspec`, `opsx`, deleted tool names, stale absolute Godot binary
   paths, and `docs/superpowers` references in tracked files.
2. Run `godot4.7 --headless --path C:\uworks\FootisesGame3 --import`.
3. Run the full headless suite with `godot4.7`; all existing tests must pass.
4. Confirm Git records only the approved deletions and documentation edits.
