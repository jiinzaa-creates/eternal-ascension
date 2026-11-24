# Eternal Ascension 1.0.0

Released 24 November 2026. This is the first release build of the 2D top-down xianxia
cultivation sandbox.

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
- Integration suite: **1198 / 0** in two consecutive final runs.
- Headless import and a 240-frame boot: exit 0 with no script or data errors.
- Linux export boots headlessly from the exported binary.
- Web export produces its HTML, wasm and pack files.

## Known limits

- The game is code-drawn except the title key art; there are no character portraits, painted
  backgrounds or imported animation frames.
- No GPU, display or audio device is available in the build environment. The title screen, HUD,
  effects and score have **not** been seen or heard; their logic is tested, their look and sound
  are not. The exports were not opened in a browser here.
- GitHub Actions has not been observed running; the tag job is configuration, not a verified run.
- Travel between provinces, flight/domain projection, profession masters and deeper economy,
  NPC feuds and the player being taken captive remain out of scope for 1.0.0.
