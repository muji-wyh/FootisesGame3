# Training Combo List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add training shortcut `4` that toggles a scrollable list of Blaze's verified combos.

**Architecture:** Store display-ready combo entries on `CharacterData`, authored by each character module. Reuse the HUD's existing two-column move-list panel by switching its title and body between move and combo modes; `TrainingScene` alone handles key `4`.

**Tech Stack:** Godot 4.7, typed GDScript, existing headless test harness and Web export.

## Global Constraints

- Show authored combos, not generated `cancel_into` permutations.
- Reuse one HUD reference panel; do not add another overlay.
- Keep `TAB` for moves and add `4` for combos only in training mode.
- A character with no authored combos displays `No authored combos.`
- Add no dependencies, playback, filtering, damage calculation, or recording.

---

### Task 1: Add Authored Combo Data and HUD Mode

**Files:**
- Modify: `scripts/combat/CharacterData.gd`
- Modify: `characters/blaze/blaze.gd`
- Modify: `scripts/ui/HUD.gd`
- Test: `tools/run_tests.gd`

**Interfaces:**
- Produces: `CharacterData.combos: PackedStringArray`
- Produces: `HUD.toggle_combo_list() -> void`
- Produces: `HUD.is_combo_list_visible() -> bool`
- Preserves: `HUD.toggle_move_list() -> void` and `HUD.is_move_list_visible() -> bool`

- [ ] **Step 1: Write the failing HUD and combo-data checks**

Extend `_test_move_list_overlay()` in `tools/run_tests.gd` after `hud.build(blaze, blaze)`:

```gdscript
	_check("Blaze authors the three verified training combos",
		blaze.combos.size() == 3
		and blaze.combos[0].contains("st.MP > 214 + MP")
		and blaze.combos[1].contains("st.HP > 214 + HP")
		and blaze.combos[2].contains("cr.LP > 214 + LK > 236236 + HP"))
	_check("combo list hidden by default", not hud.is_combo_list_visible())
	hud.toggle_combo_list()
	_check("combo list opens on toggle",
		hud.is_combo_list_visible() and not hud.is_move_list_visible())
	var combo_left: Label = hud._move_list_labels[0]
	_check("combo list shows every authored Blaze combo",
		combo_left.text.contains("Cinder Chain Confirm")
		and combo_left.text.contains("Furnace Hooks Punish")
		and combo_left.text.contains("Ember Lift Super"))
	hud.toggle_move_list()
	_check("move list replaces combo list in the shared panel",
		hud.is_move_list_visible() and not hud.is_combo_list_visible())
	hud.toggle_combo_list()
	_check("combo list replaces move list in the shared panel",
		hud.is_combo_list_visible() and not hud.is_move_list_visible())
	hud.toggle_combo_list()
	_check("combo list closes on second combo toggle",
		not hud.is_combo_list_visible() and not hud.is_move_list_visible())
```

- [ ] **Step 2: Run the suite and confirm the new API is missing**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: non-zero exit because `CharacterData.combos`, `toggle_combo_list()`, and
`is_combo_list_visible()` do not exist.

- [ ] **Step 3: Add the minimal authored data**

Add beside the move arrays in `scripts/combat/CharacterData.gd`:

```gdscript
var combos: PackedStringArray = []
```

Assign Blaze's verified routes after `c.blurb` in `characters/blaze/blaze.gd`:

```gdscript
	c.combos = PackedStringArray([
		"Cinder Chain Confirm\nst.MP > 214 + MP",
		"Furnace Hooks Punish\nst.HP > 214 + HP",
		"Ember Lift Super\ncr.LP > 214 + LK > 236236 + HP",
	])
```

- [ ] **Step 4: Reuse the existing HUD panel for combo mode**

Add mode constants and panel state in `scripts/ui/HUD.gd`:

```gdscript
const REFERENCE_MOVES := "moves"
const REFERENCE_COMBOS := "combos"

var _move_list_title: Label
var _move_list_hint: Label
var _move_list_body: Control
var _move_list_characters := [null, null]
var _move_list_mode := REFERENCE_MOVES
```

Replace the current `toggle_move_list()` and `is_move_list_visible()` with:

```gdscript
func toggle_move_list() -> void:
	_toggle_reference_panel(REFERENCE_MOVES)

func toggle_combo_list() -> void:
	_toggle_reference_panel(REFERENCE_COMBOS)

func is_move_list_visible() -> bool:
	return _move_list_panel != null and _move_list_panel.visible and _move_list_mode == REFERENCE_MOVES

func is_combo_list_visible() -> bool:
	return _move_list_panel != null and _move_list_panel.visible and _move_list_mode == REFERENCE_COMBOS

func _toggle_reference_panel(mode: String) -> void:
	if not _move_list_panel:
		return
	if _move_list_panel.visible and _move_list_mode == mode:
		_move_list_panel.visible = false
		return
	_set_reference_mode(mode)
	_move_list_panel.visible = true
	_move_list_scroll.scroll_vertical = 0
```

In `_build_move_list()`, store `p1`, `p2`, the title, hint, body, and labels, then call
`_set_reference_mode(REFERENCE_MOVES)` after the labels are assigned:

```gdscript
	_move_list_characters = [p1, p2]
	_move_list_title = _label(_move_list_panel, Vector2(24, 18), Vector2(MOVE_LIST_W - 48.0, 34), 28)
	_move_list_hint = _label(_move_list_panel, Vector2(24, 52), Vector2(MOVE_LIST_W - 48.0, 24), 16)
	_move_list_body = body
	_move_list_labels[0] = left
	_move_list_labels[1] = right
	_set_reference_mode(REFERENCE_MOVES)
```

Add the shared content switch and combo formatter:

```gdscript
func _set_reference_mode(mode: String) -> void:
	_move_list_mode = mode
	var shows_combos := mode == REFERENCE_COMBOS
	_move_list_title.text = "COMBO LIST" if shows_combos else "MOVE LIST"
	_move_list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_move_list_title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.4))
	_move_list_hint.text = "%s: close  |  wheel / drag: scroll" % ("4" if shows_combos else "TAB")
	_move_list_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for side in range(2):
		var ch: CharacterData = _move_list_characters[side]
		var label: Label = _move_list_labels[side]
		label.text = _combo_list_text(ch) if shows_combos else _move_list_text(ch)
	var body_h := maxf(_move_list_labels[0].get_minimum_size().y, _move_list_labels[1].get_minimum_size().y)
	for label in _move_list_labels:
		label.size = Vector2(240.0, body_h)
	_move_list_body.custom_minimum_size = Vector2(0, body_h)

func _combo_list_text(ch: CharacterData) -> String:
	var lines := [ch.display_name.to_upper(), ""]
	if ch.combos.is_empty():
		lines.append("No authored combos.")
	else:
		for combo in ch.combos:
			lines.append(combo)
			lines.append("")
	return "\n".join(lines).strip_edges()
```

- [ ] **Step 5: Run the full suite**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: all tests pass with `0 failed`.

- [ ] **Step 6: Commit the data and HUD behavior**

```powershell
git add scripts\combat\CharacterData.gd characters\blaze\blaze.gd scripts\ui\HUD.gd tools\run_tests.gd
git commit -m "Add authored training combo list" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Wire Training Shortcut 4

**Files:**
- Modify: `scripts/match/TrainingScene.gd`
- Test: `tools/run_tests.gd`

**Interfaces:**
- Consumes: `HUD.toggle_combo_list() -> void`
- Produces: training-only physical key `4` shortcut
- Produces: `TrainingScene._shortcut_label: Label`

- [ ] **Step 1: Write the failing training shortcut checks**

Add after the training HUD combo-counter check in `_test_training_mode()`:

```gdscript
	_check("training shortcut hint includes combo list",
		scene._shortcut_label.text.contains("4 combos"))
	var combo_key := InputEventKey.new()
	combo_key.keycode = KEY_4
	combo_key.pressed = true
	scene._unhandled_input(combo_key)
	_check("training key 4 opens the combo list", scene.hud.is_combo_list_visible())
	scene._unhandled_input(combo_key)
	_check("training key 4 closes the combo list", not scene.hud.is_combo_list_visible())
```

- [ ] **Step 2: Run the suite and confirm the shortcut state is missing**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: non-zero exit because `_shortcut_label` is missing and key `4` is not handled.

- [ ] **Step 3: Add the training-only shortcut**

Add the field in `scripts/match/TrainingScene.gd`:

```gdscript
var _shortcut_label: Label
```

Replace the local label in `_build_training_overlay()`:

```gdscript
	_shortcut_label = Label.new()
	_shortcut_label.position = Vector2(190, 112)
	_shortcut_label.size = Vector2(900, 48)
	_shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shortcut_label.add_theme_font_size_override("font_size", 18)
	_shortcut_label.add_theme_color_override("font_color", Color(0.76, 0.9, 1.0))
	_shortcut_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_shortcut_label.add_theme_constant_override("outline_size", 5)
	_shortcut_label.text = "TRAINING: idle dummy  |  TAB moves  |  1 hitboxes  |  2 slow 30%  |  3 frame meter  |  4 combos  |  ESC menu"
	_training_overlay.add_child(_shortcut_label)
```

Handle key `4` after key `3` in `_unhandled_input()`:

```gdscript
		if event.keycode == KEY_4:
			hud.toggle_combo_list()
			return
```

- [ ] **Step 4: Run full simulation verification**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: all tests pass with `0 failed`.

- [ ] **Step 5: Export and inspect the Web build**

Run:

```powershell
godot4.7 --headless --export-release "Web" web-build\index.html --path .
python tools\serve.py
```

Open `http://localhost:8090/testblaze`, focus the canvas, press `4`, and verify:

- the title is `COMBO LIST`;
- all three Blaze combos appear in both columns;
- the panel scroll behavior is unchanged;
- `TAB` switches the same panel back to `MOVE LIST`;
- pressing `4` again closes the combo list;
- DevTools reports no console or network errors.

- [ ] **Step 6: Commit the training shortcut**

```powershell
git add scripts\match\TrainingScene.gd tools\run_tests.gd
git commit -m "Add training combo list shortcut" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
