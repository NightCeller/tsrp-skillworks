# Changelog

## 3.0.0-alpha.1 — development candidate, 2026-11-04

- Added practical XP on successful crafting and ATM payouts, with configurable
  rewards/curve, difficulty reduction and saved per-skill cooldowns.
- Added `arp_skill_xp`; retained `arp_skills` schema/levels and existing filenames.
  Level/XP/cooldown awards commit atomically; Apollo economy remains separate.
- Added V3 activity registration/award natives and live `/skills` overview/details.
- Education preserves partial XP, clears it at cap; admin level edits clear it.
  Practical awards are suppressed during study. Fighting/Law get no practical XP.
- Verified ATM wallet update before awarding XP; retained existing action checks.
- Added upgrade/rollback guide and progression/SQL tests. All eight plugins compile
  without warnings; 26 automated checks pass. V3 runtime testing remains pending.
- V2 Flashlight configuration test was reported working before this development;
  other V2 acceptance checks are not assumed completed.

## 2.0.0-alpha.1 — development candidate, 2026-11-04

- Added per-recipe enable switches and skill requirements for Cooking, Weapons,
  General and Drugs. Cooking durations and ingredient pack prices are configurable.
- Added configurable Fighting and Law job-entry skill thresholds.
- Added a shared strict integer reader. Text, fractions, negative numbers, overflow
  and out-of-range settings block the affected action instead of becoming zero.
- Confirmation checks reject changed costs, durations, skill requirements or gains.
  Timed actions cancel on their next check if relevant settings change or become
  invalid; no completion charge, consumable use or reward. ATM cooldowns remain.
- Cooking pack purchases check the displayed price again and verify wallet changes;
  a failed wallet write removes the just-added pack. These remain Core-managed
  operations, not a durable transaction across separate stores.
- Cooking retains Core error state rather than marking itself ready afterward.
- Experimental Fighting damage defaults to zero in code as well as examples.
  Its configured maximum is now a whole-number percentage (0..25).
- Unified all eight plugin versions at 2.0.0-alpha.1. Added the project-owned
  SkillWorks_Config.inc and updated build scripts to find it.
- Preserved recipe balance, item names, plugin filenames, commands and database
  schemas. No migration, import or new teacher/education feature.
- Compiled all eight plugins with AMXX 1.10.0.5487 without warnings; 12 Python
  contract/distribution tests passed. v2 game-server testing remains pending.

## 0.1.0-alpha.1 — release candidate, 2026-11-04

First independent source package; subsequently uploaded to the public repository by the maintainer.

- Collected eight matching server-tested source snapshots and reviewed configurations.
- Added installation/build scripts, command/default documentation, contribution
  guidance, issue templates, source-only CI and distribution checks.
- Added project/licence comments without changing gameplay code or plugin versions.
- Public Fighting configuration disables untested bonus (uploaded config had 25).
- Corrected stale config comments for Skills and General.
- Excluded databases, logs, admin users, credentials, map data, binaries and assets.

### Development milestones included

- Skills 0.2.1: seven persisted skill values, administrator commands, paid self-study
  and Apollo chat registration.
- Cooking 0.3.0: ingredient inventory and food crafting.
- Computers 0.4.0: ATM gameplay and persistent player/ATM cooldowns.
- Weapons 0.5.0: inventory weapon crafting.
- General 0.6.1: utility crafting; unavailable individual items no longer fail all recipes.
- Drugs 0.7.0: consumable inventory crafting.
- Fighting 0.8.0: jobs and experimental capped unarmed bonus.
- Law 0.9.0: legal job selection; reconnect/full restart persistence confirmed.

See docs/TESTING.md for the distinction between reported gameplay and pending checks.
