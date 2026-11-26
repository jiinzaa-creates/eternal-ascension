# MASTER DESIGN DIRECTIVE — ETERNAL ASCENSION

> **Provenance and completeness note (added 2026-11-26, filing the recovered text)**
>
> - Source: supplied by Jawanza Martindale on 2026-11-24 as a chat paste (side chat, 2026-11-24), together with the Master Development Roadmap in the same paste.
> - The stored paste was recovered in full from the chat record for this filing: 64,516 characters covering Directive §§1–24 and the complete Roadmap (M00–M72), ending "END OF MASTER ROADMAP." An earlier audit reading of the paste was cut off mid-§3 (Passives) by a tool output limit; that truncation was in the reading, not in the stored paste. This file reproduces the Directive portion **verbatim** — no paraphrase, no completion, no edits beyond this header.
> - The Roadmap portion of the same paste is filed in `docs/MASTER_DEVELOPMENT_ROADMAP.md`.
> - Where this Directive conflicts with the implementation, the conflict is recorded, not resolved, in the compliance matrix and its 2026-11-26 addendum (contradictions C1–C12).

---

# PROJECT: ETERNAL ASCENSION
## Master Game Development Directive

You are my Lead Game Designer, Game Systems Architect, Senior Gameplay Programmer, World Designer, Technical Artist, and QA Director.

Your assignment is to design and build a complete 2D open-world sandbox action RPG centered on Chinese cultivation fantasy (Xianxia).

You are responsible for turning this concept into a cohesive, playable, expandable game.

Do not reduce this project to a linear RPG, survival game, menu simulator, idle cultivation game, or conventional top-down dungeon crawler.

The player must experience genuine freedom in a persistent cultivation world.

# 1. CORE GAME VISION

Create a 2D open-world cultivation RPG featuring:

- Seamless exploration across a massive continent.
- Real-time action combat.
- Deep character progression.
- Procedurally generated equipment and techniques.
- Cultivation, breakthroughs, tribulations, and enlightenment.
- Independent sects with competing interests.
- NPCs with routines, personalities, ambitions, and relationships.
- Hidden realms and ancient inheritances.
- Forging, crafting, stealing, trading, and experimentation.
- Player-founded sects and organizations.
- Emergent events, faction warfare, and world simulation.
- Multiple possible paths to immortality and supremacy.

The game should prioritize systemic depth, player agency, replayability, and meaningful progression.

Design inspiration:
- Skyrim: open-world exploration, player freedom, discoverable locations, fast travel.
- Path of Exile 2: itemization, affixes, build diversity, skill interactions.
- Terraria: exploration, secrets, crafting, world discovery.
- Kenshi: emergent stories, factions, consequences, and freedom.
- Cultivation novels: realms, spiritual roots, physiques, techniques, inheritance, tribulations, and sect politics.

These are design references, not assets or systems to copy.

# 2. CHARACTER DEVELOPMENT SYSTEM

Character identity must emerge from interacting systems rather than a conventional class selection.

Every character is defined by:

1. Six primary attributes.
2. Passives.
3. Techniques.
4. Physiques.
5. Spiritual roots.
6. Cultivation realm and sublevel.
7. Cultivation method.
8. Equipment and artifacts.
9. Titles, achievements, and acquired traits.

There must be no conventional hard character-level cap.

## 2.1 Primary Attributes

Implement six primary attributes:

- DEX — Dexterity
- STR — Strength
- AGI — Agility
- INT — Intelligence
- WIS — Wisdom
- CHAR — Charisma

All attributes must be uncapped.

Attributes must have meaningful mechanical effects and interact with each other.

Examples:

DEX:
- Weapon precision.
- Attack accuracy.
- Critical hit potential.
- Technique execution.
- Weapon handling.

STR:
- Physical damage.
- Carrying capacity.
- Physical resistance.
- Heavy weapon effectiveness.
- Physical cultivation requirements.

AGI:
- Movement speed.
- Attack speed.
- Dodge effectiveness.
- Animation recovery.
- Combat responsiveness.

INT:
- Technique comprehension.
- Spell complexity.
- Formation understanding.
- Crafting efficiency.
- Knowledge acquisition.

WIS:
- Qi control.
- Qi recovery.
- Cultivation comprehension.
- Enlightenment opportunities.
- Resistance to mental interference.

CHAR:
- Negotiation.
- Recruitment.
- Leadership.
- Social influence.
- Sect management.
- Relationship development.

Attributes must also influence:
- Cultivation speed.
- Qi capacity.
- Qi recovery.
- Breakthrough success.
- Tribulation survival.
- Technique mastery.
- Lifespan where appropriate.

Do not make attributes independent numerical bonuses with no meaningful interactions.

Create formulas that support specialization, hybrid builds, and diminishing returns where appropriate.

Do not impose hard caps.

# 3. PASSIVE SYSTEM

Passives are permanent or conditionally active character properties.

There must be no arbitrary passive acquisition cap.

Passives can originate from:

- Physiques.
- Spiritual roots.
- Cultivation methods.
- Titles.
- Achievements.
- Rare encounters.
- Enlightenment.
- Manuals.
- Inheritances.
- Special events.
- Training.
- Unique items.

Passives should range from minor improvements to transformative abilities.

Examples:
- Heavenly Qi Absorption.
- Iron Bone Constitution.
- Spiritual Perception.
- Bloodline Suppression.
- Sword Heart.
- Regenerative Meridian.
- Void Resistance.
- Natural Formation Affinity.
- Beast Taming Instinct.

Create passive categories:
- Physical.
- Spiritual.
- Elemental.
- Combat.
- Cultivation.
- Mental.
- Social.
- Crafting.
- Exploration.
- Special/Unique.

Passives must interact with techniques, attributes, roots, physiques, and equipment.

Implement passive synergies and conflicts.

# 4. TECHNIQUE SYSTEM

Techniques are acquired through:

- Manuals.
- Teachers.
- Sect instruction.
- Ancient inheritances.
- Observation.
- Combat experience.
- Exploration.
- Special events.

Techniques can be:

- Active attacks.
- Spells.
- Defensive abilities.
- Movement abilities.
- Healing abilities.
- Summons.
- Formations.
- Transformations.
- Passive techniques.
- Cultivation techniques.

Each technique should have:
- Rank.
- Requirements.
- Qi cost.
- Cooldown or recovery.
- Animation.
- Startup frames.
- Active frames.
- Recovery frames.
- Range.
- Damage or effect.
- Scaling attributes.
- Scaling passives.
- Upgrade paths.
- Mastery progression.

Techniques should support combinations and interactions.

Allow players to discover stronger variations through experimentation and mastery.

Do not arbitrarily limit the number of learned techniques.

# 5. PHYSIQUE SYSTEM

Physiques are exceptionally rare supernatural constitutions.

They should feel like major character-defining discoveries.

Physiques may be acquired through:
- Rare cultivation methods.
- Extreme training.
- Rare environmental conditions.
- Bloodline inheritance.
- Tribulations.
- Hidden realms.
- Special encounters.
- Unusual combinations of circumstances.

Examples:
- Chaotic Origin Physique.
- Nine Yang Divine Body.
- Heavenly Sword Constitution.
- Eternal Wood Body.
- Void Spirit Physique.
- Dragon Blood Physique.
- Immortal Bone Constitution.

Each physique should have:
- Unique passive properties.
- Attribute interactions.
- Cultivation bonuses.
- Combat benefits.
- Potential weaknesses.
- Evolution requirements.
- Possible awakening stages.

Physiques should be discoverable rather than selected from a character creation menu.

Some should be unique or extraordinarily rare.

Avoid making every physique a straightforward upgrade. Include tradeoffs and specialized advantages.

# 6. SPIRITUAL ROOT SYSTEM

Create 12 spiritual root tiers.

Use the following provisional structure:

1. Mortal Root
2. Low-Grade Root
3. Ordinary Root
4. Superior Root
5. Profound Root
6. Earth Root
7. Heaven Root
8. Spiritual Root
9. Divine Root
10. Saint Root
11. Immortal Root
12. Primordial Root

These names and classifications may be refined during design.

Each root should influence:
- Cultivation speed.
- Elemental affinity.
- Qi absorption.
- Qi purity.
- Method compatibility.
- Breakthrough requirements.
- Technique comprehension.

Roots should support elemental and special affinities.

Examples:
- Fire.
- Water.
- Wood.
- Metal.
- Earth.
- Wind.
- Lightning.
- Ice.
- Yin.
- Yang.
- Space.
- Time.
- Chaos.

Allow multiple affinities and unusual combinations.

Higher tiers should be dramatically rarer.

Do not make spiritual roots the sole determinant of character potential. Training, physiques, methods, enlightenment, and opportunities must allow unexpected development.

# 7. CULTIVATION SYSTEM

Cultivation is the central progression system.

Create 12 major cultivation realms, each containing 10 sublevels.

That gives 120 progression stages.

Every major realm breakthrough should provide a substantial increase in:
- Attributes.
- Maximum Qi.
- Qi recovery.
- Lifespan.
- Combat capability.
- Technique potential.
- Spiritual perception.
- Available cultivation methods.

Individual sublevels should provide smaller incremental benefits.

The difference between realms must be substantial.

Create a progression architecture that supports uncapped attributes and long-term development.

Each realm must have:
- Unique visual effects.
- Cultivation requirements.
- Breakthrough conditions.
- Possible bottlenecks.
- Unique risks.
- Appropriate lifespan.
- New abilities or system unlocks.
- Tribulation requirements where applicable.

Create 12 distinct realm identities. Do not simply rename generic RPG levels.

## 7.1 Cultivation Methods

Cultivation methods determine HOW the character cultivates.

Different methods must have different progression mechanics.

Examples:

Traditional cultivation:
- Accumulate Qi.
- Reach bottlenecks.
- Break through.

Body cultivation:
- Train physically.
- Survive increasingly dangerous conditioning.
- Consume rare materials.

Blood cultivation:
- Absorb compatible blood essence.
- Hunt supernatural creatures.
- Risk corruption.

Sword cultivation:
- Practice sword techniques.
- Develop sword intent.
- Experience combat enlightenment.

Dual cultivation:
- Requires compatible partners.
- Develops through mutual participation.
- Has relationship and compatibility considerations.

Slaughter cultivation:
- Requires defeating enemies.
- Accumulates killing intent.
- Carries mental and karmic risks.

Heavenly cultivation:
- Requires rare celestial resources.
- Uses environmental conditions.
- May involve special tribulations.

Create many more methods with distinct mechanics.

Methods must be discoverable, learnable, replaceable, combinable where compatible, and potentially customizable.

Some methods should require activities rather than passive resource accumulation.

## 7.2 Breakthroughs and Tribulations

Breakthroughs must be meaningful events.

Implement:
- Bottlenecks.
- Failed breakthroughs.
- Injury.
- Qi deviation.
- Mental instability.
- Resource requirements.
- Environmental requirements.
- Tribulations.
- Rare breakthrough opportunities.

Tribulations should respond to player behavior, cultivation method, realm, physique, karma, and accumulated power.

Create different tribulation types:
- Lightning.
- Heart demons.
- Elemental.
- Heavenly judgment.
- Bloodline.
- Spatial.
- Spiritual.

Success should feel earned.

# 8. WORLD DESIGN

Create one enormous, continuous Xianxia continent.

The overworld must be explorable on foot.

Do not divide ordinary regions into disconnected maps or instances.

Only hidden realms should exist outside the main overworld.

The world should include:

- Mortal towns.
- Cities.
- Villages.
- Markets.
- Farms.
- Mountains.
- Forests.
- Spirit beast territories.
- Ancient ruins.
- Dangerous wilderness.
- Rivers and lakes.
- Spiritual mountains.
- Mining regions.
- Cultivation resource locations.
- Sect territories.
- Forbidden regions.
- Ancient battlefields.
- Abandoned settlements.
- Hidden entrances.
- Dungeons and underground locations.

Build a large, coherent geography.

The player should be able to travel between settlements, explore wilderness, discover locations, and encounter things naturally.

Use a world map and an interactive local map.

## 8.1 Exploration

Exploration must be rewarding.

Include:
- Environmental storytelling.
- Treasure discoveries.
- Rare resource nodes.
- Random encounters.
- Wandering cultivators.
- Beast territories.
- Hidden caves.
- Ancient manuals.
- Secret entrances.
- Treasure maps.
- Randomized events.

Use procedural generation for appropriate content, not everything.

Handcraft important landmarks, cities, sects, and narrative locations.

## 8.2 Fast Travel

Implement Skyrim-style fast travel.

Requirements:
- Discover locations before fast travel becomes available.
- Fast travel through the world map.
- Travel restrictions in dangerous circumstances.
- Time passes during travel.
- Random encounters can interrupt travel.
- Certain locations require special access.
- Cultivation abilities may eventually unlock advanced travel.

# 9. SECT SYSTEM

Create 12 unique established sects, in addition to the sect the player can establish.

Each sect must have:
- Distinct philosophy.
- Cultivation specialty.
- Territory.
- Leadership.
- Internal hierarchy.
- Unique techniques.
- Unique cultivation methods.
- Unique resources.
- NPC population.
- Relationships with other sects.
- Internal conflicts.
- Questlines.
- Unique inheritance.

Suggested sect archetypes:

1. Heavenly Sword Sect.
2. Azure Cloud Sect.
3. Crimson Lotus Sect.
4. Thousand Beast Sect.
5. Celestial Formation Sect.
6. Blood Moon Palace.
7. Eternal Medicine Valley.
8. Shadow Veil Sect.
9. Thunder Sovereign Sect.
10. Frozen Heaven Palace.
11. Golden Cauldron Sect.
12. Void Scripture Pavilion.

These are starting concepts. Develop distinct identities and ensure each feels like an actual organization.

## 9.1 Sect Hierarchy

Create meaningful positions:
- Sect Master.
- Deputy Sect Master.
- Elders.
- Core Disciples.
- Inner Disciples.
- Outer Disciples.
- Servants.
- Specialized instructors.
- Guardians.

NPCs should occupy these positions and have their own ambitions.

The player can:
- Join.
- Advance.
- Become an elder.
- Become sect master.
- Establish a new sect.
- Recruit disciples.
- Appoint leaders.
- Create branches.
- Form alliances.
- Wage war.
- Absorb rival organizations.
- Leave or betray a sect.

Sect management should be systemic rather than menu-only.

## 9.2 Player-Founded Sect

Allow players to establish their own sect.

The player should determine:
- Name.
- Philosophy.
- Location.
- Recruitment policies.
- Cultivation specialization.
- Hierarchy.
- Laws.
- Relationships.
- Expansion strategy.

Sects should grow organically.

Include:
- Disciple recruitment.
- Training.
- Resource management.
- Buildings.
- Territory.
- Research.
- Sect missions.
- Defense.
- Diplomacy.
- Internal politics.
- Inheritance development.

# 10. NPC SIMULATION

NPCs must function as independent characters.

Each significant NPC should have:
- Name.
- Attributes.
- Cultivation realm.
- Root.
- Physique where applicable.
- Techniques.
- Equipment.
- Personality.
- Background.
- Goals.
- Relationships.
- Allegiances.
- Schedule.
- Memory.
- Opinions.
- Current activities.

NPCs should have daily routines.

Examples:
- Training.
- Cultivating.
- Shopping.
- Working.
- Traveling.
- Hunting.
- Teaching.
- Socializing.
- Fighting.
- Exploring.
- Resting.

## 10.1 Relationships

Support:
- Friendship.
- Rivalry.
- Mentorship.
- Romance.
- Marriage.
- Family.
- Loyalty.
- Betrayal.
- Hostility.

NPCs should remember meaningful interactions.

## 10.2 Recruitment and Party System

Allow players to:
- Recruit companions.
- Invite NPCs into their sect.
- Form parties.
- Assign tasks.
- Give equipment.
- Teach techniques.
- Develop relationships.
- Send NPCs on expeditions.

Party members should fight using their actual builds.

## 10.3 Slavery and Captivity

Include slavery, imprisonment, forced labor, and captive mechanics as optional world systems.

Treat them as consequential systems involving morality, reputation, laws, escape attempts, rebellion, loyalty, and faction responses.

Do not reduce NPCs to interchangeable inventory objects.

# 11. COMBAT SYSTEM

Create responsive real-time 2D action combat.

The player should move using:

- W — Up.
- A — Left.
- S — Down.
- D — Right.
- Mouse — Aiming, targeting, attacking, and interacting with applicable combat controls.

Support keyboard and mouse customization.

Combat must combine:
- Movement.
- Positioning.
- Timing.
- Animations.
- Attack recovery.
- Dodging.
- Blocking.
- Parries.
- Skill combinations.
- Resource management.
- Attributes.
- Equipment.
- Passives.
- Techniques.

Avoid simplistic stat-check combat.

## 11.1 Skill Loadout

Create three customizable skill bars.

Each bar contains six skills.

Total equipped capacity: 18 skills.

Allow:
- Switching between bars.
- Custom key bindings.
- Drag-and-drop customization.
- Skill cooldown indicators.
- Qi cost indicators.
- Animation previews.
- Contextual skill information.

The player may learn more skills than can be equipped.

## 11.2 Combat Quality

Combat must feel responsive and satisfying.

Implement:
- Distinct attack animations.
- Hit reactions.
- Knockback.
- Stagger.
- Interruptions.
- Invulnerability frames where appropriate.
- Attack telegraphs.
- Hitboxes and hurtboxes.
- Projectile interactions.
- Collision.
- Boss phases.
- Elite enemy behaviors.

Animations must affect timing and combat windows.

Stats should influence combat without making animations irrelevant.

# 12. PROCEDURAL ITEMIZATION

Use Path of Exile 2 as the inspiration for item generation.

Generate items from:
- Base item types.
- Rarity.
- Prefixes.
- Suffixes.
- Implicit modifiers.
- Affixes.
- Elemental properties.
- Cultivation bonuses.
- Randomized rolls.
- Special modifiers.
- Set interactions.

Item categories:
- Weapons.
- Armor.
- Accessories.
- Rings.
- Necklaces.
- Talismans.
- Pills.
- Materials.
- Manuals.
- Artifacts.
- Spiritual treasures.
- Consumables.

Support rarity tiers and meaningful affix combinations.

Items should interact with character builds.

Examples:
- Qi regeneration.
- Sword damage.
- Critical chance.
- Cultivation speed.
- Elemental penetration.
- Physical resistance.
- Spirit beast damage.
- Technique cooldown.
- Breakthrough assistance.

## 12.1 Special Items

Some items must be handcrafted.

Examples:
- Legendary artifacts.
- Unique weapons.
- Ancient inheritances.
- Sect treasures.
- Divine materials.
- Named manuals.

These should have fixed identities and special properties.

Do not generate everything randomly.

## 12.2 Item Manipulation

Allow players to:
- Forge.
- Refine.
- Fuse.
- Upgrade.
- Enchant.
- Personalize.
- Disassemble.
- Trade.
- Steal.
- Repair.
- Identify.
- Experiment.

Include failure chances and meaningful material costs where appropriate.

# 13. ECONOMY AND CRAFTING

Create a functioning economy.

Include:
- Multiple currencies.
- Mortal money.
- Spirit stones.
- Rare cultivation currencies.
- Merchant inventories.
- Supply and demand.
- Resource scarcity.
- Regional specialties.
- Auctions.
- Black markets.
- Trading.
- Forging.
- Alchemy.
- Formation creation.
- Artifact crafting.

Crafting professions should support character specialization.

NPC merchants and sects should participate in the economy.

# 14. HIDDEN REALMS

Hidden realms are separate maps and should be the only major locations separated from the continuous overworld.

They should be procedurally generated within carefully designed templates.

Examples:
- Ancient Immortal Ruins.
- Secret Beast Realms.
- Forgotten Battlefields.
- Heavenly Gardens.
- Abandoned Sects.
- Trial Realms.
- Spatial Fractures.
- Ancient Tombs.
- Forbidden Domains.

Each hidden realm should feature:
- Unique environments.
- Environmental hazards.
- Special enemies.
- Exploration.
- Random events.
- Treasure.
- Inheritances.
- Possible bosses.
- Exit conditions.

## 14.1 Discovery

Players may discover hidden realms through:
- Exploration.
- Rumors.
- Treasure maps.
- NPC information.
- Sect assignments.
- Ancient manuals.
- Random world events.
- Rare environmental phenomena.

Some realms should appear for limited periods.

Others should be extremely difficult to locate.

## 14.2 Inheritances

Hidden realms should contain some of the game's most valuable inheritances.

Inheritance rewards may include:
- Unique cultivation methods.
- Rare physiques.
- Techniques.
- Ancient artifacts.
- Spiritual roots upgrades.
- Passive abilities.
- Bloodline transformations.
- Special crafting recipes.

Do not guarantee the best rewards.

Use weighted random loot tables and separate reward sources.

A dungeon completion reward must not automatically guarantee its boss's rare drop.

Create a distinction between:
- Exploration rewards.
- Boss drops.
- Dungeon completion rewards.
- Quest rewards.
- Hidden inheritance rewards.

# 15. DYNAMIC WORLD EVENTS

The world must continue functioning without player intervention.

Create:
- Sect wars.
- Beast invasions.
- Resource discoveries.
- Merchant caravans.
- Cultivator duels.
- Political conflicts.
- Natural disasters.
- Tribulations.
- Ancient realm openings.
- Treasure competitions.
- NPC expeditions.
- Assassinations.
- Sect succession conflicts.

Events should be affected by:
- Time.
- Region.
- Player reputation.
- Sect relationships.
- NPC goals.
- World state.
- Randomness.

The player should hear rumors about events before or during their occurrence.

Allow NPCs and sects to discover and pursue opportunities independently.

# 16. STORY AND QUEST DESIGN

Story should emerge from the world rather than restrict the player.

Each of the 12 established sects must have a unique major questline.

Every sect questline should:
1. Introduce the sect.
2. Allow the player to join.
3. Test the player's abilities.
4. Introduce internal politics.
5. Reveal a meaningful conflict.
6. Offer opportunities for advancement.
7. Lead to a unique inheritance.
8. Provide a path to a high-ranking sect position.

The player should be able to become:
- An elder.
- A sect master.
- A guardian.
- A leader of a specialized division.
- A powerful independent cultivator.

Do not make every questline follow the same structure.

Create meaningful choices and consequences.

Some sects should have mutually exclusive opportunities.

Others may become allies or enemies depending on player actions.

## 16.1 Main Narrative

Create an overarching narrative that connects:
- The continent's history.
- Ancient cultivation civilizations.
- The origins of spiritual roots.
- The existence of primordial physiques.
- Ancient sect conflicts.
- Hidden realms.
- The nature of immortality.
- The ultimate purpose of cultivation.

Do not force the player into a predetermined heroic identity.

Allow the player to pursue personal ambitions.

Possible endgame directions:
- Become an immortal.
- Found the strongest sect.
- Conquer the continent.
- Discover the origin of cultivation.
- Become a legendary artifact creator.
- Master forbidden cultivation.
- Establish a new cultivation civilization.
- Pursue an alternative form of transcendence.

The main story should support these paths without requiring one specific ending.

# 17. ART AND PRESENTATION

Create a visually compelling 2D world.

Recommended direction:
- Detailed 2D environments.
- Top-down or 3/4 perspective.
- Layered landscapes.
- Atmospheric lighting.
- Weather.
- Day/night cycles.
- Animated vegetation.
- Distinct regional architecture.
- Beautiful cultivation effects.
- Visually recognizable techniques.
- Distinct character silhouettes.
- High-quality combat animations.

The world should feel alive even when the player is standing still.

Avoid placeholder graphics in the final production build.

# 18. AUDIO

Create an atmospheric soundscape.

Include:
- Regional ambient sound.
- Weather.
- Combat sounds.
- Weapon impacts.
- Technique audio.
- Cultivation audio.
- Beast sounds.
- Town ambience.
- Sect themes.
- Boss music.
- Hidden realm music.

Audio must communicate combat timing and environmental information.

# 19. TECHNICAL ARCHITECTURE

Before implementing the full game, inspect the existing repository.

Do not assume an engine, architecture, or project state without verification.

Build modular systems with clear boundaries.

Recommended subsystems:

- Character System.
- Attribute System.
- Passive System.
- Technique System.
- Physique System.
- Spiritual Root System.
- Cultivation System.
- Combat System.
- Item Generation System.
- Inventory and Equipment System.
- Crafting System.
- World Simulation.
- NPC Simulation.
- Relationship System.
- Party System.
- Sect System.
- Quest System.
- Hidden Realm Generator.
- Economy System.
- Event System.
- Save/Load System.
- UI System.
- Audio System.

All important systems should be data-driven.

Use deterministic procedural generation where possible.

Use stable IDs for generated content and save references.

Design for future expansion without rewriting foundational systems.

# 20. SAVE SYSTEM

Create a reliable persistent save system.

Save:
- Player character.
- Attributes.
- Passives.
- Techniques.
- Physiques.
- Roots.
- Cultivation.
- Equipment.
- Inventory.
- NPC relationships.
- NPC states where persistent.
- Sect information.
- World events.
- Quest progression.
- Discovered locations.
- Hidden realm seeds and states.
- Economy.
- Time and world state.

Implement versioned saves, migration support, backups, and corruption recovery.

Test saving and loading throughout development.

# 21. DEVELOPMENT PROCESS

Do not immediately attempt to generate the entire game.

First perform a complete repository and technical audit.

Then produce:

1. Current project assessment.
2. Technical architecture.
3. Game Design Document.
4. Core system dependency map.
5. World design document.
6. Combat specification.
7. Cultivation progression specification.
8. Itemization specification.
9. NPC and faction simulation specification.
10. Quest and narrative framework.
11. Milestone implementation plan.
12. QA strategy.

Identify design conflicts and recommend solutions before implementation.

Prioritize a playable vertical slice.

The vertical slice must include:
- Character creation.
- A functioning overworld.
- Player movement.
- At least one populated settlement.
- Basic NPC routines.
- Cultivation.
- Attributes.
- Roots.
- Passives.
- Techniques.
- Real-time combat.
- Procedurally generated items.
- Inventory and equipment.
- One dungeon or hidden realm.
- One sect.
- One meaningful questline.
- Saving and loading.

After the vertical slice is verified, expand the game incrementally.

# 22. QUALITY ASSURANCE

Act as an independent QA director.

Every milestone must include:
- Implementation report.
- Files changed.
- Systems affected.
- Automated test results.
- Manual playtest instructions.
- Known issues.
- Performance results.
- Regression results.
- Save/load verification.
- Acceptance criteria.

Never claim a system is complete because a menu, placeholder, or data structure exists.

A system is complete only when it works in actual gameplay.

Verify:
- Character attributes affect gameplay.
- Cultivation methods have functional progression.
- Breakthroughs work.
- Techniques can be learned and used.
- Passives activate.
- Physiques provide their benefits.
- Equipment modifiers affect combat.
- NPCs perform routines.
- Sects function.
- Hidden realms generate playable environments.
- Loot comes from the correct sources.
- Saves preserve world state.

Never fabricate test results.

Never silently remove existing functionality.

Never replace implemented systems with mockups to make a milestone appear complete.

# 23. DESIGN PRINCIPLES

Follow these principles throughout development:

1. Player freedom over linear progression.
2. Systemic depth over superficial feature count.
3. Meaningful choices over arbitrary restrictions.
4. Discovery over excessive handholding.
5. Emergent gameplay over scripted repetition.
6. Distinct builds over one optimal build.
7. Living NPCs over static quest dispensers.
8. Meaningful rewards over guaranteed loot.
9. World consistency over procedural randomness.
10. Playability over feature checklists.

The world should not revolve around the player.

Power should be earned, discovered, inherited, stolen, crafted, or cultivated.

Rare things must remain rare.

# 24. FIRST RESPONSE REQUIREMENTS

Your first response must NOT begin implementation.

Start by auditing the existing repository and reporting:

- Engine and version.
- Existing project structure.
- Existing gameplay systems.
- Current implementation status.
- Existing assets.
- Missing dependencies.
- Technical limitations.
- Potential architectural risks.

Then present the proposed architecture and milestone plan.

Identify contradictions and unresolved design decisions.

Recommend improvements where they materially improve the game.

Do not ask me to design every detail. Act as the lead designer and make informed recommendations.

Ask me one important clarification at a time when a decision genuinely requires my input.

Your objective is not to create a small demonstration of a cultivation RPG.

Your objective is to build a deep, expandable, fully playable open-world cultivation sandbox.
