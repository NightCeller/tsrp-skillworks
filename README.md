# TSRP SkillWorks

**Independent skills and progression addons for The Specialists Roleplay.**
Built for Apollo-RP, AMX Mod X and SQLite. Maintained by [NightCeller](https://github.com/NightCeller).

> v2 development candidate: `2.0.0-alpha.1`. Source distribution; no precompiled plugins.
> This is an independent community project, not an official Apollo-RP release and
> not affiliated with or endorsed by its maintainers. v2 has compiled successfully; in-game upgrade testing is pending.

SkillWorks adds seven persistent skills, paid self-study, inventory crafting,
ATM gameplay and skill-gated jobs. It extends an existing working Apollo server;
it is not a replacement roleplay framework or a complete server download.

| Module | Plugin version | Gameplay |
| --- | --- | --- |
| Skills | 2.0.0-alpha.1 | Seven skills, range 0–100, SQLite persistence and bank-funded study |
| Cooking | 2.0.0-alpha.1 | Ingredient packs, Fries, Hamburger and Pizza |
| Computers | 2.0.0-alpha.1 | ATM attempts with persistent player and ATM cooldowns |
| Weapons | 2.0.0-alpha.1 | Six existing Apollo weapon inventory items |
| General | 2.0.0-alpha.1 | Flashlight, Tape where available, Lockpick and Electric Lockpick |
| Drugs | 2.0.0-alpha.1 | Four existing fictional-game consumable inventory items |
| Fighting | 2.0.0-alpha.1 | Dojo Worker/Fighter jobs; experimental unarmed bonus disabled by default |
| Law | 2.0.0-alpha.1 | Lawyer, Jury and City Judge job selection |

## New in v2

Recipe enable switches, skill requirements, costs and durations are configurable.
Cooking pack prices and Fighting/Law job thresholds are configurable too. Strict
integer validation blocks malformed settings instead of interpreting text as zero.
Confirmation menus detect changed terms, and timed actions cancel when relevant
settings change. Existing saves and command names are preserved.

Read [v2 upgrade and first test](docs/UPGRADING-V2.md) and
[configuration reference](docs/CONFIGURATION.md). Education additions and engine
CRC troubleshooting remain deferred. This is an alpha, not a tested stable v2 release.

## Start here

1. Read [installation and build instructions](docs/INSTALL.md).
2. Use the [command reference](docs/COMMANDS.md) and [gameplay/defaults guide](docs/GAMEPLAY.md).
3. Review [testing status and limitations](docs/TESTING.md) before public-server use.
4. See the [roadmap](ROADMAP.md), [changelog](CHANGELOG.md) and [contribution guide](CONTRIBUTING.md).

### Requirements

- Half-Life dedicated server and The Specialists 3.0.
- AMX Mod X 1.10 (maintainer tested build 5487), Metamod and the usual TS modules.
- A working Apollo-RP 1.3 installation in **SQLite** mode with authenticated Steam IDs.
- Apollo item/NPC/chat plugins needed by the selected modules; see the installation guide.

The maintainer's tests used Windows, `mecklenburgv5_a6`, HLDS build 10210 and a
locally patched Apollo Core (`diag3-quiet`). Stock Core and Linux runtime
compatibility have **not** been established. The Core patch is not bundled or
installed by this repository. No MySQL or LAN-only identity support is claimed.

### Data and compatibility

`ARP_Skills` creates `arp_skills`; `ARP_Computers` creates
`arp_computer_cooldowns` in Apollo's database. Do not import a database or rerun
map SQL to install these addons. Keep existing `ARP_` filenames, cvars and tables
when updating: they remain for compatibility, not to imply official affiliation.
Gameplay addons read skill values; self-study and admin commands change them.
No automatic XP is awarded for crafting, fighting or job changes.

Only skill sources and clean configuration examples are included. No player
records, administrator accounts, credentials, logs, game assets or server binaries.

## Licence and credits

Project code is distributed under **GPL-3.0-or-later**, with the Half-Life linking
exception stated in [NOTICE](NOTICE). See [LICENSE](LICENSE) and
[credits/provenance](docs/CREDITS.md). External dependencies retain their own licences.
