# QA AND ACCEPTANCE STRATEGY

*Design document #16 of the M01 set (see `docs/DESIGN_DOCUMENTS.md`). Filed
2026-11-26 as a state-of-record document: the strategy below is taken from the
Master Design Directive §22 (Quality Assurance), the Master Development
Roadmap's milestone-report and Final Definition of Done requirements, and the
project's actual test practice. It describes the standard work is held to; it
does not claim any milestone currently meets it.*

## 1. The acceptance rule (Directive §22)

A system is complete only when it works in actual gameplay. Never claim a
system is complete because a menu, placeholder, or data structure exists.
Never fabricate test results. Never silently remove existing functionality.
Never replace implemented systems with mockups to make a milestone appear
complete.

Every milestone report must include: implementation report, files changed,
systems affected, automated test results, manual playtest instructions, known
issues, performance results, regression results, save/load verification, and
acceptance criteria.

Gameplay verification must establish, per system, that it functions in play —
for example: character attributes affect gameplay; cultivation methods have
functional progression; breakthroughs work; techniques can be learned and
used; passives activate; physiques provide their benefits; equipment modifiers
affect combat; NPCs perform routines; sects function; hidden realms generate
playable environments; loot comes from the correct sources; saves preserve
world state.

## 2. Verification statuses

Work is reported under exactly these statuses (Independent Code Reviewer
charter, 2026-11-24): COMPLETE AND VERIFIED · IMPLEMENTED, NOT FULLY VERIFIED ·
PARTIALLY IMPLEMENTED · PLACEHOLDER / MOCKUP · BROKEN · MISSING · BLOCKED.
A status of COMPLETE AND VERIFIED requires successful gameplay verification,
not code inspection alone. As of the Compliance Matrix v2 and the 2026-11-26
addendum, no milestone carries that status.

## 3. Automated testing (current practice)

- **Unit + content suite** — `game/tests/run_tests.tscn`, run headless:
  `godot --headless --path game res://tests/run_tests.tscn`.
  Covers data-registry integrity (every registered biome/item/technique must
  resolve its content), deterministic generation (same seed → same payload),
  formulas, save round-trips, and per-system rules. This is the deterministic
  gate: it must report FAIL 0 before any commit lands.
- **Integration suite** — `game/tests/integration.tscn`: boots the real game
  and plays scripted scenarios (streaming, NPC routines, travel, combat,
  saves). On shared/low-CPU environments individual checks are timing
  sensitive; a failure is a regression signal only when it is deterministic
  or new against the recorded baseline pool, and the comparison must be
  stated when results are reported.
- **CI** — `.github/workflows/ci.yml` runs import + both suites + a boot
  check on Godot 4.4.1; exports are tag-only.
- **Visual harness** — `game/tests/visual_check.gd` renders real scenes for
  screenshot review; presentation changes are verified from screenshots of
  the running game, never from code alone.

## 4. Determinism and save integrity

- All procedural content is a pure function of (world seed, coordinates)
  through `Rng.stream()` / `Rng.stream_from()`; tests pin reproducibility.
- Save/load must preserve world state: the world is rebuilt from the saved
  seed on load before state is re-applied (a seed-mismatch defect found and
  fixed 2026-11-26 is the standing example of why this is tested, not
  assumed).
- Existing saves must never be silently destroyed by a change; migrations
  and legacy-format reads are covered in the unit suite.

## 5. Performance practice

Frame cost is watched where the design is heaviest: chunk streaming (worker
threads, pure payloads), NPC counts in settlements, and off-screen
simulation. Performance claims require measurements with stated conditions;
none are asserted without them.

## 6. Open gaps against this strategy

- No hands-on (non-headless) gameplay verification has been performed by the
  reviewer; the web export has never been played in a browser.
- The QA working registers required by the reviewer charter (`docs/qa/` —
  compliance matrix, bug register, regression register, gameplay
  verification log, technical debt, milestone audit history) live outside
  the repo as audit files; standing them up inside the repo remains open.
