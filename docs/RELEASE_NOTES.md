# Eternal Ascension 1.0.1

Released 24 November 2026. This is the first release build of the 2D top-down xianxia
cultivation sandbox.

## Patch 1.0.1 — browser pass

The 1.0.0 build was opened in a browser and three defects surfaced:

- The HUD was built at zero size when the main scene replaced the title, so centered creation text
  and the right and bottom panels were clipped off-screen. It now syncs its size on ready and on
  every viewport resize, and an integration check pins the HUD to the live viewport.
- The title footer used arrow glyphs the fallback font lacks, which rendered as tofu boxes; it now
  reads `UP / DOWN choose · ENTER confirm · ESC quit`.
- The control help was drawn through the combat skill bar and the toasts. It now wraps in a block
  above the skill bar, and toasts clear both.

At 1280×720 the title, key art and menu are legible; **Begin a new life** walks creation, identity
and into play; **Continue** reloads populated slot 1 and reports `Loaded slot 1.`. Audio is still
unheard (see Known limits).

## What ships

- A streamed province with a populated Azure Cloud Market, nineteen scheduled residents,
  day/night lighting, weather, roofs that fade behind the player and a deterministic continent map.
- Real-time frame-data combat: chained weapon strikes, six technique slots, guard and parry,
  dodge i-frames, four elemental statuses, elites, spirit beasts, bosses and a tribulation.
- Cultivation from Qi Condensation to the peak: roots, physiques, methods, meridians,
  enlightenments, breakthroughs and a real death/aging clock.
- Nine hidden-realm families, each with a generated layout, hazards, a warden, an inheritance
  altar and a trial; rifts open on a deterministic calendar and carry rumors.
- Four quest chains, twelve three-chapter sect storylines with regard and endings, a market
  chronicle, faction standing, a player sect, a council and a quartermaster.
- Four archaeological narrative threads that converge on one blank page: **F8** writes the run's
  single irreversible ending.
- A settings and accessibility screen on **F10**: high contrast, reduced motion, damage numbers,
  sound and music volume, captivity content, and rebinding of twenty-two actions.
- A read-only character sheet on **C**, the satchel, map, chronicle, sect, narrative and endgame
  screens — all drawn in code, all freezing play rather than letting a click become an attack.
- A title screen with painted key art, **Continue** for the highest populated save slot, and a
  synthesized ambient score that follows the sound settings.
- A crash-safe save system: atomic writes, SHA-256 verification, three rotating backups,
  corruption fallback and schema migration at schema 2.

## Run a build

With Godot 4.4.1 and its export templates installed:

```bash
mkdir -p game/build/linux game/build/web
godot --headless --path game --export-release "Linux"
godot --headless --path game --export-release "Web"
```

The Linux artifact is a single executable with the pack embedded. The Web artifact is a static
`index.html`/wasm/pck bundle; serve it over HTTP (no cross-origin isolation is required because the
Web preset is exported without thread support).

## Verification at release

- Unit suite: **4330 / 0**.
- Integration suite: **1199 / 0** in the final run after the 1.0.1 fixes.
- Headless import and a 240-frame boot: exit 0 with no script or data errors.
- Linux export boots headlessly from the exported binary.
- Web export produces its HTML, wasm and pack files and was opened at 1280×720: title, key art and
  menu legible; New Life reached creation, identity and play; Continue loaded slot 1.

## Known limits

- The game is code-drawn except the title key art; there are no character portraits, painted
  backgrounds or imported animation frames.
- No audio device is available in the build environment. The synthesized score has **not** been
  heard; its logic, settings and F2 mute path are tested, its sound is not.
- The browser pass covered the title, both menu paths, creation and a resumed run at 1280×720;
  a full playthrough, small-window layout below 1280 and every screen were not re-checked.
- GitHub Actions has not been observed running; the tag job is configuration, not a verified run.
- Travel between provinces, flight/domain projection, profession masters and deeper economy,
  NPC feuds and the player being taken captive remain out of scope for 1.0.1.
