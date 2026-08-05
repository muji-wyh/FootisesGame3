# Blaze Complex Combo Relay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6/8-hit meterless Blaze relays, a 13-hit super relay, and a 14-hit DRC max route using two FightingAnimsetPro clips.

**Architecture:** Define `Ember Barrage` and `Cinder Rise` as ordinary `MoveData` specials in Blaze's existing character module. Reuse normal `cancel_into`, multi-hit cadence, motion parsing, DRC, super cancellation, and the authored training combo list; no new runtime subsystem is needed.

**Tech Stack:** Godot 4.7.1, typed GDScript, deterministic 60 Hz simulation, existing headless harness, Web export.

## Global Constraints

- `st.MK` remains the cancel-free mid-range ruler.
- `cr.MK` gains no new cancel target.
- `Ember Barrage` is `236 + LP` using `KB_p_OneTwoThree`.
- `Cinder Rise` is `623 + MP` using `KB_m_Backelbow_Uppercut_R`.
- Full relays require late input; do not add last-hit-only cancel state.
- Keep normal first-hit hit-stop and shorter multi-hit follow-up stops.
- Add no combo manager, rekka state, chain-only move type, custom per-hit timeline, or dependency.
- All timing remains fixed 60 Hz ticks.

## File Map

- `characters/blaze/blaze.gd` - owns both moves, cancel routes, combo-list text, animation clips, impact fractions, hitboxes, and balance values.
- `tools/run_tests.gd` - owns move-data, cancel-graph, route, resource, hit-count, and training-list regression checks.

---

### Task 1: Add the Core Multi-Hit Relay

**Files:**
- Modify: `characters/blaze/blaze.gd:43-215,255-262`
- Modify: `tools/run_tests.gd:32-110,121-180,1380-1430,2530-2660`

**Interfaces:**
- Produces: Blaze special `ember_barrage: MoveData`
- Produces: Blaze special `cinder_rise: MoveData`
- Produces: `_p1_dp(ctx: Dictionary, button: int) -> void`
- Produces: `_wait_for_combo_count(ctx: Dictionary, defender: Fighter, target: int, limit: int = 90) -> bool`
- Preserves: `MoveData`, `Fighter`, `MotionParser`, and `HUD` APIs unchanged

- [ ] **Step 1: Write the failing helper and relay checks**

Add these helpers after `_p1_qcb()` in `tools/run_tests.gd`:

```gdscript
func _p1_dp(ctx: Dictionary, button: int) -> void:
	_step(ctx, _mk(1, 0), _neutral(), 2)
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1, button), _neutral(), 1)

func _wait_for_combo_count(ctx: Dictionary, defender: Fighter, target: int,
		limit: int = 90) -> bool:
	for i in range(limit):
		if defender.combo_count >= target:
			return true
		_step(ctx, _neutral(), _neutral(), 1)
	return defender.combo_count >= target
```

Call the new test immediately after `_test_blaze_combo_expansion()` in `_initialize()`:

```gdscript
	_test_blaze_combo_expansion()
	_test_blaze_complex_relay()
```

Add this test after `_test_blaze_combo_expansion()`:

```gdscript
func _test_blaze_complex_relay() -> void:
	print("[blaze complex relay]")
	var blaze := CharacterLibrary.create("blaze")
	var barrage := blaze.get_move("ember_barrage")
	var rise := blaze.get_move("cinder_rise")

	_check("Ember Barrage is 236 + LP",
		barrage != null
		and barrage.kind == GameConst.MoveKind.SPECIAL
		and barrage.button == GameConst.Btn.LP
		and barrage.motion == MotionParser.QCF)
	_check("Ember Barrage uses the measured three-punch clip",
		barrage != null
		and barrage.anim_clip == "KB_p_OneTwoThree"
		and barrage.hits == 3
		and barrage.hit_gap == 13
		and barrage.cancel_into == ["cinder_rise"])
	_check("Cinder Rise is 623 + MP",
		rise != null
		and rise.kind == GameConst.MoveKind.SPECIAL
		and rise.button == GameConst.Btn.MP
		and rise.motion == MotionParser.DP)
	_check("Cinder Rise uses the measured elbow-uppercut clip",
		rise != null
		and rise.anim_clip == "KB_m_Backelbow_Uppercut_R"
		and rise.hits == 2
		and rise.hit_gap == 9
		and rise.launch
		and rise.cancel_into == ["super_inferno"])
	_check("only selected close checks enter the first relay stage",
		blaze.get_move("st_lp").cancel_into.has("ember_barrage")
		and blaze.get_move("st_lk").cancel_into.has("ember_barrage")
		and blaze.get_move("cr_lp").cancel_into.has("ember_barrage")
		and not blaze.get_move("cr_lk").cancel_into.has("ember_barrage"))
	_check("mid-range rulers gain no relay cancel",
		not blaze.get_move("st_mk").cancel_into.has("ember_barrage")
		and not blaze.get_move("cr_mk").cancel_into.has("ember_barrage"))

	var full := _build()
	var fa: Fighter = full["f1"]
	var fb: Fighter = full["f2"]
	fa.position.x = -0.34
	fb.position.x = 0.34
	_step(full, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	var full_ok := _wait_for_combo_count(full, fb, 1)
	_p1_qcf(full, GameConst.Btn.LP)
	full_ok = full_ok and _wait_for_combo_count(full, fb, 4)
	_p1_dp(full, GameConst.Btn.MP)
	full_ok = full_ok and _wait_for_combo_count(full, fb, 6)
	_check("late st.LP relay reaches all 6 hits", full_ok and fb.combo_count >= 6)
	full["arena"].queue_free()

	var early := _build()
	var ea: Fighter = early["f1"]
	var eb: Fighter = early["f2"]
	ea.position.x = -0.34
	eb.position.x = 0.34
	_step(early, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_wait_for_combo_count(early, eb, 1)
	_p1_qcf(early, GameConst.Btn.LP)
	_wait_for_combo_count(early, eb, 2)
	_p1_dp(early, GameConst.Btn.MP)
	var early_max := eb.combo_count
	for i in range(70):
		_step(early, _neutral(), _neutral(), 1)
		early_max = maxi(early_max, eb.combo_count)
	_check("early DP cancel intentionally truncates Ember Barrage",
		early_max >= 4 and early_max < 6)
	early["arena"].queue_free()
```

Replace the first three `expected_routes` entries in `_test_blaze_combo_expansion()`:

```gdscript
		"st_lp": ["flame_step_l", "ember_lift", "ember_barrage"],
		"st_lk": ["flame_step_l", "ember_lift", "ember_barrage"],
		"cr_lp": ["flame_step_l", "ember_lift", "ember_barrage"],
```

Replace the authored-combo check in `_test_move_list_overlay()`:

```gdscript
	_check("Blaze authors the existing routes plus Quick Relay",
		blaze.combos.size() == 4
		and blaze.combos[0].contains("st.MP > 214 + MP")
		and blaze.combos[1].contains("st.HP > 214 + HP")
		and blaze.combos[2].contains("cr.LP > 214 + LK > 236236 + HP")
		and blaze.combos[3].contains("st.LP > 236 + LP > 623 + MP"))
```

Extend the move-list and combo-list checks:

```gdscript
	_check("move list shows Blaze combo tools",
		left.text.contains("Flame Step")
		and left.text.contains("Cinder Lash")
		and left.text.contains("Ember Wheel")
		and left.text.contains("Cinder Chain")
		and left.text.contains("Furnace Hooks")
		and left.text.contains("Ember Barrage")
		and left.text.contains("Cinder Rise"))
```

```gdscript
	_check("combo list shows every authored Blaze combo",
		left.text.contains("Cinder Chain Confirm")
		and left.text.contains("Furnace Hooks Punish")
		and left.text.contains("Ember Lift Super")
		and left.text.contains("Quick Relay"))
```

- [ ] **Step 2: Run the harness and verify the new moves are absent**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: non-zero exit with failures for `Ember Barrage is 236 + LP`, `Cinder Rise is 623 + MP`, the new cancel routes, and the 6-hit relay.

- [ ] **Step 3: Add the two moves, close-check wiring, and Quick Relay**

In `NORMAL_TUNING`, append `"ember_barrage"` to only these three cancel arrays:

```gdscript
	"st_lp": {"startup": 4, "active": 3, "recovery": 9, "damage": 27, "hitstun": 16, "blockstun": 9, "hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 3.6, "hit_offset": Vector3(0.57, 1.35, 0.0), "hit_size": Vector3(0.37, 0.62, 0.55), "cancel_into": ["flame_step_l", "ember_lift", "ember_barrage"], "hit_reaction_clip": "KB_Hit_m_HighRight_Weak", "hit_fx": HIT_FX + "Thin01.png"},
	"st_lk": {"startup": 5, "active": 3, "recovery": 9, "damage": 29, "hitstun": 14, "blockstun": 9, "hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 3.3, "hit_offset": Vector3(0.66, 0.72, 0.0), "hit_size": Vector3(0.46, 0.34, 0.62), "cancel_into": ["flame_step_l", "ember_lift", "ember_barrage"], "hit_fx": HIT_FX + "Thin02.png"},
	"cr_lp": {"startup": 4, "active": 3, "recovery": 9, "damage": 25, "hitstun": 13, "blockstun": 9, "hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 3.4, "hit_offset": Vector3(0.58, 0.95, 0.0), "hit_size": Vector3(0.37, 0.34, 0.55), "cancel_into": ["flame_step_l", "ember_lift", "ember_barrage"], "hit_fx": HIT_FX + "Effect01.png"},
```

Append Quick Relay to `c.combos`:

```gdscript
	c.combos = PackedStringArray([
		"Cinder Chain Confirm\nst.MP > 214 + MP",
		"Furnace Hooks Punish\nst.HP > 214 + HP",
		"Ember Lift Super\ncr.LP > 214 + LK > 236236 + HP",
		"Quick Relay\nst.LP > 236 + LP > 623 + MP",
	])
```

Add the specials after `Cinder Chain` and before `Furnace Hooks`:

```gdscript
	c.add_move(CharacterKit.make_move({"id": "ember_barrage", "display_name": "Ember Barrage",
		"kind": GameConst.MoveKind.SPECIAL, "button": GameConst.Btn.LP,
		"motion": MotionParser.QCF, "startup": 5, "active": 30, "recovery": 20,
		"damage": 16, "hits": 3, "hit_gap": 13, "hitstun": 19, "blockstun": 14,
		"hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 2.4,
		"advance": 1.8, "meter_gain": 8, "hit_fx": HIT_FX + "Effect01.png", "sfx": "lp",
		"anim_limb": "arm_l", "anim_extend": 0.8, "anim_clip": "KB_p_OneTwoThree",
		"hit_offset": Vector3(0.69, 1.45, 0.0),
		"hit_size": Vector3(0.36, 0.42, 0.58),
		"cancel_into": ["cinder_rise"]}))

	c.add_move(CharacterKit.make_move({"id": "cinder_rise", "display_name": "Cinder Rise",
		"kind": GameConst.MoveKind.SPECIAL, "button": GameConst.Btn.MP,
		"motion": MotionParser.DP, "startup": 7, "active": 14, "recovery": 28,
		"damage": 24, "hits": 2, "hit_gap": 9, "hitstun": 20, "blockstun": 12,
		"hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 3.2,
		"advance": 3.0, "launch": true, "launch_velocity": 5.8,
		"meter_gain": 10, "hit_fx": HIT_FX + "Effect08.png", "sfx": "mp",
		"anim_limb": "arm_r", "anim_extend": 0.9,
		"anim_clip": "KB_m_Backelbow_Uppercut_R",
		"hit_offset": Vector3(0.42, 1.46, 0.0),
		"hit_size": Vector3(0.30, 0.46, 0.66),
		"cancel_into": ["super_inferno"]}))
```

Add the measured first-impact fractions to `r.clip_impacts`:

```gdscript
		"KB_m_KickUppercut_R": 0.31, "KB_m_Jab_RLhookRMidKick_combo": 0.13,
		"KB_p_DoubleHooks": 0.22, "KB_p_OneTwoThree": 0.073,
		"KB_m_Backelbow_Uppercut_R": 0.200, "KB_Superpunch": 0.50,
```

- [ ] **Step 4: Verify the authored hitboxes cover the measured limbs**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/probe_hitheight.gd -- blaze
```

Expected: `ember_barrage` covers hand height `1.32..1.58`, `cinder_rise` covers hand height `1.30..1.61`, neither row ends in `MISS`, and the final summary reports `0 move(s) with the hitbox outside the striking limb.`

- [ ] **Step 5: Run the full harness**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: all checks pass with `0 failed`, including the 6-hit delayed relay and the shorter early-cancel route.

- [ ] **Step 6: Commit the core relay**

```powershell
git add characters\blaze\blaze.gd tools\run_tests.gd
git commit -m "Add Blaze relay specials" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Add Heavy, Super, and DRC Conversions

**Files:**
- Modify: `characters/blaze/blaze.gd:43-95`
- Modify: `tools/run_tests.gd:1380-1430,2530-2740`

**Interfaces:**
- Consumes: `ember_barrage`, `cinder_rise`, `_p1_dp()`, and `_wait_for_combo_count()`
- Produces: `_p1_heavy_relay(ctx: Dictionary) -> bool`
- Produces: authored `Heavy Relay`, `Inferno Relay`, and `Max Heat` training entries
- Preserves: `st.MK.cancel_into == []` and the existing `cr.MK.cancel_into`

- [ ] **Step 1: Write the failing long-route checks**

Add this helper before `_test_blaze_complex_relay()`:

```gdscript
func _p1_heavy_relay(ctx: Dictionary) -> bool:
	var defender: Fighter = ctx["f2"]
	_step(ctx, _mk(0, -1, GameConst.Btn.MP), _neutral(), 1)
	if not _wait_for_combo_count(ctx, defender, 1):
		return false
	_step(ctx, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	if not _wait_for_combo_count(ctx, defender, 2):
		return false
	_step(ctx, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	if not _wait_for_combo_count(ctx, defender, 3):
		return false
	_p1_qcf(ctx, GameConst.Btn.LP)
	if not _wait_for_combo_count(ctx, defender, 6):
		return false
	_p1_dp(ctx, GameConst.Btn.MP)
	return _wait_for_combo_count(ctx, defender, 8)
```

Append these checks before `_test_blaze_complex_relay()` ends:

```gdscript
	_check("st.HP enters Ember Barrage without changing the medium rulers",
		blaze.get_move("st_hp").cancel_into.has("ember_barrage")
		and not blaze.get_move("st_mk").cancel_into.has("ember_barrage")
		and not blaze.get_move("cr_mk").cancel_into.has("ember_barrage"))

	var heavy := _build()
	var ha: Fighter = heavy["f1"]
	var hb: Fighter = heavy["f2"]
	ha.position.x = -0.34
	hb.position.x = 0.34
	var heavy_hp := hb.health
	var heavy_ok := _p1_heavy_relay(heavy)
	_check("Heavy Relay reaches all 8 meterless hits",
		heavy_ok and hb.combo_count >= 8 and hb.health < heavy_hp and hb.health > 0)
	heavy["arena"].queue_free()

	var inferno := _build()
	var ia: Fighter = inferno["f1"]
	var ib: Fighter = inferno["f2"]
	ia.position.x = -0.34
	ib.position.x = 0.34
	ia.meter = ia.character.max_meter
	var inferno_ok := _p1_heavy_relay(inferno)
	_p1_qcf(inferno, 0)
	_p1_qcf(inferno, GameConst.Btn.HP)
	inferno_ok = inferno_ok and _wait_for_combo_count(inferno, ib, 13, 120)
	_check("Inferno Relay reaches all 13 hits",
		inferno_ok and ib.combo_count >= 13 and ib.health > 0)
	_check("Inferno Relay spends the full Super meter", ia.meter == 0)
	inferno["arena"].queue_free()

	var max_heat := _build()
	var ma: Fighter = max_heat["f1"]
	var mb: Fighter = max_heat["f2"]
	ma.position.x = -0.34
	mb.position.x = 0.34
	ma.meter = ma.character.max_meter
	var drive_before := ma.drive
	_step(max_heat, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	var max_ok := _wait_for_combo_count(max_heat, mb, 1)
	_step(max_heat, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var entered_drc := false
	for i in range(36):
		_step(max_heat, _neutral(), _neutral(), 1)
		if ma.state == Fighter.State.DRIVE_RUSH:
			entered_drc = true
			break
	_step(max_heat, _mk(0, -1, GameConst.Btn.MP), _neutral(), 1)
	max_ok = max_ok and entered_drc and _wait_for_combo_count(max_heat, mb, 2)
	_step(max_heat, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	max_ok = max_ok and _wait_for_combo_count(max_heat, mb, 3)
	_step(max_heat, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	max_ok = max_ok and _wait_for_combo_count(max_heat, mb, 4)
	_p1_qcf(max_heat, GameConst.Btn.LP)
	max_ok = max_ok and _wait_for_combo_count(max_heat, mb, 7)
	_p1_dp(max_heat, GameConst.Btn.MP)
	max_ok = max_ok and _wait_for_combo_count(max_heat, mb, 9)
	_p1_qcf(max_heat, 0)
	_p1_qcf(max_heat, GameConst.Btn.HP)
	max_ok = max_ok and _wait_for_combo_count(max_heat, mb, 14, 120)
	_check("Max Heat reaches all 14 hits", max_ok and mb.combo_count >= 14)
	_check("Max Heat spends three Drive bars",
		ma.drive <= drive_before - Fighter.DRC_COST + 100)
	_check("Max Heat spends Super without a full-health KO",
		ma.meter == 0 and mb.health > 0)
	_check("Max Heat never crosses through the defender", ma.position.x < mb.position.x)
	max_heat["arena"].queue_free()
```

Replace the `st_hp` entry in `_test_blaze_combo_expansion()`:

```gdscript
		"st_hp": ["flame_surge", "flame_step_m", "flame_step_h", "cinder_lash", "ember_wheel", "super_inferno", "cinder_chain", "furnace_hooks", "ember_barrage"],
```

Replace the combo-data check in `_test_move_list_overlay()`:

```gdscript
	_check("Blaze authors all seven verified training combos",
		blaze.combos.size() == 7
		and blaze.combos[3].contains("Quick Relay")
		and blaze.combos[4].contains("Heavy Relay")
		and blaze.combos[5].contains("Inferno Relay")
		and blaze.combos[6].contains("Max Heat"))
```

Extend the combo-panel check:

```gdscript
	_check("combo list shows every authored Blaze combo",
		left.text.contains("Cinder Chain Confirm")
		and left.text.contains("Furnace Hooks Punish")
		and left.text.contains("Ember Lift Super")
		and left.text.contains("Quick Relay")
		and left.text.contains("Heavy Relay")
		and left.text.contains("Inferno Relay")
		and left.text.contains("Max Heat"))
```

- [ ] **Step 2: Run the harness and verify the heavy branch is missing**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: failures for the `st.HP` Barrage cancel, seven-combo list, 8-hit Heavy Relay, 13-hit Inferno Relay, and 14-hit Max Heat.

- [ ] **Step 3: Wire the committed heavy starter and publish all routes**

Append `"ember_barrage"` to only `st_hp.cancel_into` in `NORMAL_TUNING`:

```gdscript
	"st_hp": {"startup": 9, "active": 4, "recovery": 18, "damage": 78, "hitstun": 21, "blockstun": 13, "hitstop": 12, "guard": GameConst.Guard.MID, "knockback": 6.0, "advance": 1.4, "hit_offset": Vector3(0.59, 1.38, 0.0), "hit_size": Vector3(0.39, 0.50, 0.68), "cancel_into": ["flame_surge", "flame_step_m", "flame_step_h", "cinder_lash", "ember_wheel", "super_inferno", "cinder_chain", "furnace_hooks", "ember_barrage"], "hit_reaction_clip": "KB_Hit_m_HighRight_Med", "hit_fx": HIT_FX + "Large01.png"},
```

Replace `c.combos` with:

```gdscript
	c.combos = PackedStringArray([
		"Cinder Chain Confirm\nst.MP > 214 + MP",
		"Furnace Hooks Punish\nst.HP > 214 + HP",
		"Ember Lift Super\ncr.LP > 214 + LK > 236236 + HP",
		"Quick Relay\nst.LP > 236 + LP > 623 + MP",
		"Heavy Relay\ncr.MP > st.MP > st.HP > 236 + LP > 623 + MP",
		"Inferno Relay\ncr.MP > st.MP > st.HP > 236 + LP > 623 + MP > 236236 + HP",
		"Max Heat\nst.MP > DRC > cr.MP > st.MP > st.HP > 236 + LP > 623 + MP > 236236 + HP",
	])
```

- [ ] **Step 4: Run the full simulation and hitbox checks**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
godot4.7 --headless --path . --script res://tools/probe_hitheight.gd -- blaze
```

Expected: the harness ends with `0 failed`; the relay reaches 8, 13, and 14 hits; `st.MK` and `cr.MK` retain their old routes; the hitbox probe reports no `MISS`.

- [ ] **Step 5: Export and visually validate the complete relay**

Run:

```powershell
godot4.7 --headless --export-release "Web" web-build\index.html --path .
python tools\serve.py
```

Open `http://localhost:8090/testblaze`. In training, use `U/I/O` for punches and `WASD` for motions:

```text
Quick Relay: U, 236+U, 623+I
Inferno Relay: crouch I, I, O, 236+U, 623+I, 236236+O
Max Heat: I, U+I, crouch I, I, O, 236+U, 623+I, 236236+O
```

Expected:

- Barrage visibly freezes on its first punch, then lands two shorter rhythmic stops.
- Rise lands elbow then uppercut without skipping either pose.
- Inferno Rush begins while the launched defender remains reachable.
- Neither fighter crosses through the other.
- Shortcut `4` shows all seven routes without clipping.
- DevTools console and network contain no new errors.

Stop the server with `Ctrl+C` after validation.

- [ ] **Step 6: Commit the complete route set**

```powershell
git add characters\blaze\blaze.gd tools\run_tests.gd
git commit -m "Add Blaze complex combo relays" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
