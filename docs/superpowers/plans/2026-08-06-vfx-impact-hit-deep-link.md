# VFX Impact and Hit Gallery Deep Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open `GALLERY-VFXImpactAndHit.tscn` directly from `/testvfximpactandhit`.

**Architecture:** Extend the existing `Main.apply_boot_link()` marker checks rather than adding a router. The same marker check supports path, hash, and query URLs while preserving match configuration.

**Tech Stack:** Godot 4.7, typed GDScript, existing headless test harness.

## Global Constraints

- Reuse `Main.apply_boot_link()` and its existing `url.contains()` behavior.
- Return `res://scenes/ui/GALLERY-VFXImpactAndHit.tscn`.
- Do not change match mode or character selection.
- Do not add a route table, router, or dependency.

---

### Task 1: Add the VFX gallery deep link

**Files:**
- Modify: `tools/run_tests.gd:1150-1180`
- Modify: `scripts/ui/Main.gd:9-31`

**Interfaces:**
- Consumes: `Main.apply_boot_link(url: String) -> String`
- Produces: recognition of the `testvfximpactandhit` URL marker

- [ ] **Step 1: Write the failing deep-link test**

Add this loop to `_test_boot_deep_link()` after the FightingAnimsetPro checks:

```gdscript
	for url in ["http://localhost:8090/testvfximpactandhit",
			"http://localhost:8090/#testvfximpactandhit",
			"http://localhost:8090/?testvfximpactandhit"]:
		game.set("mode", GameConst.Mode.LOCAL_2P)
		game.set("p1_char_id", "")
		game.set("p2_char_id", "")
		_check("%s boots the VFXImpactAndHit gallery" % url,
			main.apply_boot_link(url) == "res://scenes/ui/GALLERY-VFXImpactAndHit.tscn")
		_check("%s leaves the match config untouched" % url,
			int(game.get("mode")) == GameConst.Mode.LOCAL_2P
			and String(game.get("p1_char_id")) == ""
			and String(game.get("p2_char_id")) == "")
```

- [ ] **Step 2: Run the suite and verify the new test fails**

Run:

```powershell
godot4.7 --headless --path . --log-file .godot\vfx-deep-link-red.log --script res://tools/run_tests.gd
```

Expected: the three VFX deep-link scene checks fail because the marker still returns the main menu.

- [ ] **Step 3: Add the minimal route**

Add the constants beside the existing gallery deep-link constants:

```gdscript
const VFX_IMPACT_AND_HIT_LINK := "testvfximpactandhit"
const VFX_IMPACT_AND_HIT_SCENE := "res://scenes/ui/GALLERY-VFXImpactAndHit.tscn"
```

Add this check in `apply_boot_link()` before the `TESTBLAZE_LINK` fallback:

```gdscript
	if url.contains(VFX_IMPACT_AND_HIT_LINK):
		return VFX_IMPACT_AND_HIT_SCENE
```

- [ ] **Step 4: Run the full suite**

Run:

```powershell
godot4.7 --headless --path . --log-file .godot\vfx-deep-link-green.log --script res://tools/run_tests.gd
```

Expected: the final `=== Results` line reports zero failures.

- [ ] **Step 5: Verify the Web deep link**

Run:

```powershell
godot4.7 --headless --export-release "Web" web-build\index.html --path .
python tools\serve.py
```

Open `http://localhost:8090/testvfximpactandhit`. Expected: the page loads the
`GALLERY-VFXImpactAndHit` scene directly with no console or network errors.

- [ ] **Step 6: Commit**

```powershell
git add scripts\ui\Main.gd tools\run_tests.gd
git commit -m "Add VFX gallery deep link"
```
