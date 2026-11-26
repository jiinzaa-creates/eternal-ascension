# ETERNAL ASCENSION — NARRATIVE SPECIFICATION

**Basis.** Requirements from Directive §16/§16.1 and roadmap M67–M69; implementation
facts from the compliance matrix (M67, M68, M69), the 2026-11-26 addendum, and the
data files themselves (`game/data/quests.json`, `game/data/sect_storylines.json`,
`game/data/main_narrative.json`).

## Requirements

- Story emerges from the world rather than restricting the player (Directive §16).
- Each of the 12 established sects has a **unique major questline** that: introduces
  the sect; lets the player join; tests the player's abilities; introduces internal
  politics; reveals a meaningful conflict; offers advancement; leads to a unique
  inheritance; and provides a path to a high-ranking sect position. The player can
  become an elder, a sect master, a guardian, a division leader, or a powerful
  independent cultivator. **Questlines must not all follow the same structure.**
  Some sects hold mutually exclusive opportunities; others may become allies or
  enemies depending on player actions.
- The main narrative (§16.1) connects the continent's history, ancient cultivation
  civilizations, the origins of spiritual roots, primordial physiques, ancient sect
  conflicts, hidden realms, the nature of immortality and the ultimate purpose of
  cultivation — without forcing a predetermined heroic identity, and supporting
  multiple endgame directions (see the GDD §11).

## Quest architecture (per M67)

- Data-driven graph in `data/quests.json`, executed by `systems/quests.gd`:
  prerequisites (quests / any / minimum realm / minimum contribution), ordered
  steps, all/any multi-objective branches, a single `report()` event channel,
  rewards granted once, and `validate()` rejecting cycles and unknowns.
- Current content: **4 quests** — `quest.azure_cloud.initiation`,
  `quest.azure_cloud.tempering`, `quest.market.ledger`, `quest.realm.first_descent`.

## Sect storylines (per M68)

- `data/sect_storylines.json`: 12 arcs, one per sect, each with a title and summary
  (e.g. Azure Cloud's "The Hoarded Vein"), a giver, unlock gates (minimum realm /
  minimum contribution), storyline prerequisites and exclusions, and **3 chapters**
  each. Chapters carry a stake, a brief, a test (collect/kill/talk-style objective),
  and **2 stances (choices)** with distinct effects (regard, faction standing).
- The three stakes are shared data: `stake.welcome` ("The Welcome"),
  `stake.fault` ("The Fault Line"), `stake.future` ("The Reckoning") — every arc's
  chapters are keyed to the same three-stake ladder.
- Regard resolves to 3 endings per arc (per M68); mutual exclusions exist
  (Blood Moon ↔ Frozen Heaven, per M68); one foreign correspondence at a time;
  the storylines screen presents houses, regard and choices.

**The C5 contradiction (open, author ruling required).** The roadmap forbids
making all twelve storylines structurally identical; the implementation's stated
design is one shared ladder (welcome / fault / reckoning) for all 12, differing in
work kind and stance payouts. Additionally, per M68: storylines do not let the
player *join* the other 11 sects, advance in them, or take a high-ranking position
in them; the "unique inheritance" of §16 is realised as stance grants, not an
inheritance campaign; and 11 arcs start from a market-board letter rather than from
visiting the sect.

## Main narrative (per M69)

- `data/main_narrative.json`: **4 threads × 4 records** — The Severed Heaven,
  The Root Question, The Physique Bloodlines, The Pavilion's Book. Each thread
  poses a question (e.g. Severed Heaven: "Why did the old civilisation's ascent
  fail?") and its records are gated by real game state; final records require
  progress in two other threads. Delivered through an archive screen; the narrative
  is ignorable by design.
- Delivery form: a record-collection/archive system. Per M69, no narrative scenes,
  characters or dialogue carry the history — within its chosen form the structure
  is complete, and its scope is narrower than "overarching story" implies.

## Supporting narrative systems

- **Emergent stories (per M54):** `systems/stories.gd` generates up to 2 beats/day
  from (seed, day, slot) with venue + ambition eligibility, witnesses and a 4-day
  rumour window; deliver/hunt requests with deadlines; a chronicle capped at 40
  entries; NPC progression events become chronicle entries. NPC memory itself is a
  regard counter + talk count — promises, grudges and family histories as distinct
  memory types are not present.
- **World events (per M66):** 8 tidings on a deterministic 5-day cycle with
  duration and effects (cultivation/prices/spawns/sect service/rift override),
  an optional task and one-time reward, announced by herald + HUD. Events are
  calendar modifiers, not simulated occurrences with actors.

## Implementation status (2026-11-26)

- Quest architecture implemented; content is 4 quests. Missing quest types (per
  M67): companion quests, dynamic/procedural quests, bounty quests as quests (hunt
  *requests* in Stories are a parallel system), quest failure/expiration, and
  branching *decisions* inside quests (choices live in the storylines).
- Storylines: 12 arcs exist and are playable as correspondence campaigns; the
  structural-distinctness requirement is unmet (C5) and joining/advancement in the
  11 foreign sects is absent.
- Main narrative: structurally complete as an archive; no scene/dialogue delivery.
- Dialogue generally: greetings, small talk, warnings and quest talk (per M50);
  **no dialogue trees or choices, and no dialogue UI** (per M50/M71).
