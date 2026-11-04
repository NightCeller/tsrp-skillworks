# TSRP SkillWorks

**Independent skills and progression for The Specialists Roleplay**, maintained by
[NightCeller](https://github.com/NightCeller). Built for Apollo-RP, AMX Mod X and SQLite.
This is not an official Apollo-RP release and is not affiliated with its maintainers.

**3.0.0-alpha.1 — source candidate.** All eight plugins compile without warnings.
26 automated checks pass. V3 has not yet been gameplay-tested; no GitHub update
or stable release is implied. Compiler outputs are not bundled.

## New in V3

- Successful Cooking, General, Weapons and Drugs crafting, and successful ATM
  payouts, earn configurable practical XP. No XP for purchases, item use, failed
  or cancelled activities, combat or job changes.
- `/skills` opens a seven-skill overview. Select a skill for its XP, learning
  instructions, current unlocks and next available unlock. Requirements and
  availability come from the installed addons and current server settings.
- XP and XP cooldowns persist by Steam ID and skill. Existing levels are retained;
  a separate table is added automatically. No database import or reset.
- Paid education remains available and is the default route to initial unlocks.
  Practical progression is slower. Easy activities award reduced XP, then none.
- V2 configurable recipes, prices, durations, thresholds and validation remain.

## Get started

1. Follow [V3 upgrade and first test](docs/UPGRADING-V3.md).
2. Read [progression settings and behaviour](docs/PROGRESSION.md).
3. See [installation/building](docs/INSTALL.md), [commands](docs/COMMANDS.md),
   [gameplay](docs/GAMEPLAY.md) and [testing limits](docs/TESTING.md).

| Module | Gameplay |
| --- | --- |
| Skills | Seven levels 0–100, partial XP, overview/detail menu and paid self-study |
| Cooking | Ingredient packs, Fries, Hamburger and Pizza; completion XP |
| Computers | ATM attempts, player/ATM cooldowns, successful-payout XP |
| Weapons | Six existing Apollo weapons; completion XP |
| General | Flashlight, Tape where available, Lockpick, Electric Lockpick; completion XP |
| Drugs | Four fictional-game consumable inventory items; completion XP |
| Fighting | Dojo Worker/Fighter jobs; experimental unarmed bonus defaults off; no practical XP |
| Law | Lawyer, Jury and City Judge jobs; no practical XP |

## Dependencies and compatibility

The Specialists 3.0, HLDS, Metamod, AMX Mod X 1.10 (compiled with 5487), and a
working Apollo-RP 1.3 server in **SQLite** mode with authenticated Steam IDs.
Use the existing Apollo/TS includes and modules. Copy all three project-owned
SkillWorks `.inc` files when compiling. Upgrade all eight plugins together,
loading `ARP_Skills` before gameplay addons.

Earlier gameplay reports used Windows, mecklenburgv5_a6 and a patched Apollo
Core (`diag3-quiet`). Stock Core, Linux runtime, MySQL and LAN identities are not
verified. Fighting damage remains untested and disabled by default.

`ARP_Skills` owns `arp_skills` and the new `arp_skill_xp`; Computers retains
`arp_computer_cooldowns`. XP/level/cooldown writes are one SQLite transaction.
Apollo money/items are saved separately; abrupt crashes can separate an economic
outcome from its XP. This alpha does not claim crash-atomic economic handling.

Only source, clean example configs and project documentation/tests are included.
No player records, admin accounts, credentials, logs, third-party binaries or assets.
See [LICENSE](LICENSE), [NOTICE](NOTICE), [credits](docs/CREDITS.md),
[changelog](CHANGELOG.md) and [roadmap](ROADMAP.md).
