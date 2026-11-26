# DESIGN DOCUMENTS — REGISTER (M01)

Milestone M01 ("Complete Game Design and Technical Specification") in the Master
Development Roadmap requires the Eternal Ascension concept to be translated into
production documentation. The roadmap's M01 text (recovered verbatim in
`docs/MASTER_DEVELOPMENT_ROADMAP.md`, appendix) lists exactly **16 documents** to
create:

> Complete Game Design Document · Technical Design Document · System dependency map ·
> Gameplay loop documentation · Character progression specification · Cultivation
> progression specification · Combat specification · World simulation specification ·
> NPC simulation specification · Itemization specification · Sect system specification ·
> Narrative and quest specification · UI/UX specification · Art direction document ·
> Audio direction document · QA and acceptance strategy.

**Audit finding that prompted this register:** Compliance Matrix v2 (2026-11-24)
scored M01 PARTIALLY IMPLEMENTED — of the 16 required documents, only the
technical/system specification partially existed (`docs/DEVELOPMENT.md`), and the
README served as a de-facto GDD summary. The 2026-11-26 addendum repeated the point:
"docs/ holds DEVELOPMENT.md + RELEASE_NOTES.md only." This register and the documents
filed alongside it on 2026-11-26 close the filing gap; they do not change any
implementation verdict.

## Governing documents

| Document | Status | Location |
|---|---|---|
| Master Design Directive (§§1–24) | Filed 2026-11-26, verbatim from the author's 2026-11-24 paste | `docs/MASTER_DESIGN_DIRECTIVE.md` |
| Master Development Roadmap (M00–M72) | Filed 2026-11-26: summary table (matrix statuses) + verbatim appendix from the same paste | `docs/MASTER_DEVELOPMENT_ROADMAP.md` |
| This register | Filed 2026-11-26 | `docs/DESIGN_DOCUMENTS.md` |

## The 16 required documents (roadmap M01 list)

| # | Required document (roadmap wording) | Status | Location / coverage |
|---|---|---|---|
| 1 | Complete Game Design Document | Filed 2026-11-26 (design + status, per the directive and the audit record) | `docs/design/GAME_DESIGN_DOCUMENT.md` |
| 2 | Technical Design Document | Partially present before this filing; a deep per-system spec, not a complete technical design document (per M01 finding) | `docs/DEVELOPMENT.md` |
| 3 | System dependency map | Filed 2026-11-26, derived from the actual code | `docs/design/SYSTEM_DEPENDENCY_MAP.md` |
| 4 | Gameplay loop documentation | No standalone document; covered as a section of the GDD | `docs/design/GAME_DESIGN_DOCUMENT.md` (§ Core loop) |
| 5 | Character progression specification | No standalone document; specified across the GDD (character identity) and `docs/DEVELOPMENT.md` (attributes, secondary stats, creation, passives, physiques, roots sections) | See locations named |
| 6 | Cultivation progression specification | No standalone document; specified across the GDD and `docs/DEVELOPMENT.md` (meridians, realms, methods, breakthroughs, tribulations, enlightenment sections) | See locations named |
| 7 | Combat specification | No standalone document; `docs/DEVELOPMENT.md` carries the combat architecture, weapons, defense, technique combat and skill bar sections | `docs/DEVELOPMENT.md` |
| 8 | World simulation specification | No standalone document; `docs/DEVELOPMENT.md` carries streaming, continent, biomes, climate and off-screen simulation sections | `docs/DEVELOPMENT.md` |
| 9 | NPC simulation specification | No standalone document; `docs/DEVELOPMENT.md` carries schedules, NPC intelligence, relationships, party, captivity, NPC progression and emergent stories sections | `docs/DEVELOPMENT.md` |
| 10 | Itemization specification | No standalone document; item architecture/generation is specified in code-adjacent sections of `docs/DEVELOPMENT.md` and the data files under `game/data/` | See locations named |
| 11 | Sect system specification | No standalone document; `docs/DEVELOPMENT.md` carries the twelve sects, hierarchy, economy, politics, player sect and autonomy sections | `docs/DEVELOPMENT.md` |
| 12 | Narrative and quest specification | Filed 2026-11-26 | `docs/design/NARRATIVE_SPECIFICATION.md` |
| 13 | UI/UX specification | Filed 2026-11-26 (the implemented UI, specified as built) | `docs/design/UI_UX_SPECIFICATION.md` |
| 14 | Art direction document | Filed 2026-11-26 as a distillation; the full working standard remains the Visual Bible | `docs/design/ART_DIRECTION.md`; full text: `game/assets/art-studio/VISUAL_BIBLE.md` |
| 15 | Audio direction document | Filed 2026-11-26 as a state-of-record document; direction itself is deferred by the author (see the document) | `docs/design/AUDIO_DIRECTION.md` |
| 16 | QA and acceptance strategy | Filed 2026-11-26 as a state-of-record document (Directive §22 + the roadmap's report/Definition of Done requirements + actual test practice) | `docs/design/QA_AND_ACCEPTANCE_STRATEGY.md` |

## Rules for this register

- A document counts as "filed" only when it exists in this repository. External audit
  files (compliance matrix, addendum) are evidence, not design documents.
- Where coverage is "a section of another document," that is stated plainly rather
  than counted as a standalone delivery.
- Statuses here describe documentation only. Implementation status lives in the
  compliance matrix and addendum, and in the status lines inside each document.
