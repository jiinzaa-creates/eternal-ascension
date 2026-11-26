# ETERNAL ASCENSION — AUDIO DIRECTION

**Status of this document.** This is a state-of-record filing for M01, not a
soundtrack plan. No audio direction has been set by the author beyond what is
recorded below, and this document invents none.

## What the Directive requires

Directive §18 requires an atmospheric soundscape: regional ambient sound, weather,
combat sounds, weapon impacts, technique audio, cultivation audio, beast sounds,
town ambience, sect themes, boss music and hidden-realm music — with audio
communicating combat timing and environmental information.

## What exists

- **All audio in the game is synthesized in code; the repository contains zero
  audio asset files** (no .wav/.mp3/.ogg under `game/`).
- `game/systems/music.gd` (autoload `Music`): the ambient score is a deterministic
  12-second loop built once from a slow drone and a pentatonic bell figure
  (A-minor pentatonic: 220.0, 261.63, 293.66, 329.63, 392.0 Hz), shared by the title
  screen and the run. Two builds are byte-identical by design.
- `game/systems/sfx.gd`: combat sounds as short synthesized streams from envelope
  specs — swing, hit, crit, guard, parry, hurt, death, art.
- `game/ui/combat_audio.gd`: the combat-audio presentation layer (per M37, combat
  audio is synthesized, 8 streams).
- The compliance matrix (M72) records: "Ambient score synthesized (12s loop),
  combat audio synthesized" — and notes audio was never heard in the build
  environment during the audit.

## The recorded decision

On 2026-11-25, when offered directions for the game's audio, Jawanza Martindale
answered **"Skip."** Audio direction is therefore **deferred by the author**.
The synthesized score and combat sounds above are the developer's interim
implementation, not an approved direction.

## Open items (for the author, when he chooses to set direction)

- Whether the synthesized approach remains the direction or recorded/composed
  assets replace it.
- Coverage against §18's list (regional ambience, weather, town ambience, sect
  themes, boss and hidden-realm music do not exist as distinct authored content).
- Any listening verification: no audio has been auditioned as part of an audit.
