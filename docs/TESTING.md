# Testing status and limits

This is an alpha source candidate, not a claim that every path is verified.
The table below describes the **pre-v2 baseline**, reported from the maintainer's
local Windows server on 2026-11-04. It is not evidence that v2 has passed gameplay tests.

| Area | Reported evidence |
| --- | --- |
| Skills storage | Values retained across reconnect and full restart; invalid/range inputs rejected |
| Self-study | Menu and bank-funded learning tested; progression observed |
| Cooking | Basic gameplay reported working; exhaustive recipe/effect matrix not recorded |
| Computers | Basic gameplay reported working; multiplayer contention not established |
| Weapons | Basic crafting reported working; exhaustive equip/ammo matrix not recorded |
| General | Flashlight crafted/used; Lockpick tested; missing Tape no longer blocks plugin |
| Drugs | Basic gameplay reported working; every effect and edge case not individually recorded |
| Fighting | Job selection reported working; unarmed damage explicitly untested |
| Law | Job selection/salary retained across reconnect and full shutdown/restart |
| Core economy | HUD, money, banking, jobs, items and normal restart persistence tested separately |

The server used TS 3.0/HD, HLDS build 10210, Metamod 1.21.1-am, AMXX 1.10.0.5487,
Apollo 1.3 and mecklenburgv5_a6, with Core marker diag3-quiet. v2 modifies these sources. The exact v2 candidate needs the
upgrade test and configuration checks below before promotion to a release.

## Automated checks

Run `python3 -m unittest discover -s tests -v` and
`python3 tools/check_package.py`. They exercise SQLite schema/conditional lesson
writes/cooldown transactions, check example cvars against registered defaults,
protect baseline recipe balance and inspect the distribution boundary. They do NOT
execute Pawn, start HLDS, prove race safety of the full server, or replace manual
tests. The included GitHub workflow runs these checks only; no compiled release is produced.

Local v2 validation: all eight sources compiled with AMXX 1.10.0.5487, the supplied
AMXX/TS headers and the documented Apollo include reference, with zero warnings.
All 12 Python tests passed. The strict Pawn parser and in-game menu/timer paths
require the live checks below; the Python tests do not execute those paths.

## Known limitations

- SQLite skill writes and Apollo wallet/bank/item persistence are not one durable
  transaction. Abrupt process loss can leave partial economic outcomes. Normal
  restart persistence tests do not prove crash-atomic payment handling.
- No MySQL, Steam ID LAN, stock-Core or Linux runtime support has been verified.
- Fighting's damage feature is experimental, disabled in public configuration;
  its compiled fallback is also zero in v2. Ham configuration validity
  is not proof of correct runtime offsets. Existing CRC warnings remain unresolved.
- ATM detection depends on Apollo NPC internals and proximity; it has no line-of-sight
  requirement. Rewards create wallet money. Cancel/death/disconnect keeps cooldown.
- Different addons can run activities simultaneously; there is no suite-wide action lock.
- Recipe outputs and ingredient types remain fixed; switches, thresholds, costs
  and times are configurable. Missing items vary by installation.
- Job thresholds govern entry through these menus only. Lowering a skill afterward
  does not fire the player. Other admin/job systems can assign independently.
- Law allows the stock `t` flag; operators must review any custom use of this flag.
- Old Stage/Apollo wording remains in some UI text for compatibility with this snapshot.

## Manual release checklist

- [x] Compile all eight v2 sources with the documented compiler/includes locally.
- [ ] Test a clean install, correct plugin order and no new runtime errors.
- [ ] Check chat and console commands, including team chat.
- [ ] Verify costs, cancellation, death, disconnect, slot reuse and insufficient funds.
- [ ] Test all item outputs/effects; unavailable outputs must not take payment.
- [ ] Verify two players cannot bypass ATM cooldowns; test restart persistence.
- [ ] Test Law at 20/21 and Fighting at 15/16; cancel job confirmation; preserve salaries.
- [ ] Confirm jobs and new skills survive normal shutdown/restart.
- [ ] Verify only intended unarmed hits receive bonus when explicitly enabled;
      test guns, armed kicks, knives, grenades, falls, armor and lethal hits.
- [ ] Re-run package privacy checks before any release.

For combat diagnostics use `arp_fighting_debug 1` briefly with a second consenting
player, compare controlled hits at skill 0 and 100, then turn debug off. Do not
report the UI's calculated bonus as proof that damage changed.

## v2 configuration acceptance checks — pending in game

Use a test server copy. Restore each setting before moving to the next check.

- [ ] Follow [UPGRADING-V2.md](UPGRADING-V2.md); saved skills, wallet, bank, job,
  inventory and HUD remain intact across reconnect and a full restart.
- [ ] Each of the four crafting menus displays edited skill/time/cost values.
  Disabling one recipe blocks only that recipe; missing Tape stays unavailable.
- [ ] Set a cost to `abc`, `1.5`, `-1`, `1000001` and a very long number in the
  server console. Each blocks that recipe without changing money or items.
  An explicit `0` cost works; duration `0` and skill `101` are rejected.
- [ ] Try invalid enable values (`2`, `abc`) and invalid job thresholds. They must
  not enable a feature or remove its threshold.
- [ ] Open a craft confirmation, change price/time/threshold, then confirm. The
  old confirmation must be rejected. Reopen to accept the updated terms.
- [ ] Start a craft, change its settings or disable it, and wait one timer tick.
  No item, charge or ingredient consumption. Another recipe's settings should
  not cancel it. Cooking pack price changes should not cancel already-started cooking.
- [ ] Open the Cooking supplies menu, change the chosen pack price, then buy.
  No charge or pack: reopen the menu to accept its new price.
- [ ] Change lesson price/time/points before confirmation and during a lesson.
  No completion payment or skill gain; include a lesson near the skill cap.
- [ ] Change ATM settings during an attempt. No reward, existing cooldown retained.
- [ ] Change Fighting/Law thresholds at runtime; check below/at the new threshold.
  Change one with a job confirmation open: it must reject the old confirmation.
- [ ] Reapply defaults and repeat one successful craft, lesson, ATM and job choice.
  Save deliberate config changes in files and verify them after a full restart.
