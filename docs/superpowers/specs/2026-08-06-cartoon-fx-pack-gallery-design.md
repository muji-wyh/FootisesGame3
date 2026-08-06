# CartoonFXPack Gallery Design

## Goal

Add `GALLERY-CartoonFXPack` to the home menu and open it directly from
`/testcartoonfxpack`.

## Gallery

Create `CartoonFXGallery.gd` as a small subclass of `AnimationGallery.gd` so it can reuse the
existing environment, camera controls, labels, notice, and gallery header.

The gallery reads the 22 PNG resources under `res://assets/cartoon_fx_pack/textures`, sorts them,
and displays each one on a labeled billboard quad. Materials are unshaded, additive, transparent,
emissive, and depth-independent so the white effect textures remain readable against the dark
gallery background. Quad dimensions preserve each texture's aspect ratio.

The preview is intentionally static. The pack contains textures rather than authored effect
scenes, and always-visible cards are cheaper and easier to compare than repeatedly allocating
short-lived `HitSpark` nodes.

If no textures are available, the gallery shows the existing missing-assets notice. Files that do
not load as `Texture2D` are skipped.

## Navigation

- Add `GALLERY-CartoonFXPack.tscn`.
- Add a `GALLERY-CartoonFXPack` button to `MainMenu.gd`.
- Recognize `testcartoonfxpack` in `Main.apply_boot_link()`.
- Support path, hash, and query spellings through the existing marker matching.
- Leave match mode and character selection untouched.

## Verification

Headless coverage will verify:

- The scene exists and the home menu links it.
- Export-style `.png.import` and `.png.remap` listings resolve to PNG resource paths.
- All 22 textures are discovered and load as `Texture2D`.
- The gallery builds readable billboard preview quads.
- Path, hash, and query deep links boot the gallery without changing match configuration.
- The extra menu button still fits the 720p viewport.

Web validation will open both the home menu and `/testcartoonfxpack`, then check the rendered
gallery, console, and network requests.

## Non-goals

- No particle or flipbook authoring.
- No mesh preview for the three debris OBJ files.
- No general-purpose route table.
- No changes to the existing VFXImpactAndHit gallery.
