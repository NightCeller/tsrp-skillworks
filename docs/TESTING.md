# Testing status and limits

This is an alpha source candidate, not a claim that every path is verified.
Reports below are from the maintainer's local Windows server on 2026-11-04.

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
Apollo 1.3 and mecklenburgv5_a6, with Core marker diag3-quiet. Source files in this
package match the uploaded gameplay code (comments/line endings aside). Public
config changes and public distribution on a clean server require another smoke test.

## Automated checks

Run `python3 -m unittest discover -s tests -v` and
`python3 tools/check_package.py`. They exercise SQLite schema/conditional lesson
writes/cooldown transactions and inspect the distribution boundary. They do NOT
execute Pawn, start HLDS, prove race safety of the full server, or replace manual
tests. The GitHub workflow runs these checks only; no compiled release is produced.

## Known limitations

- SQLite skill writes and Apollo wallet/bank/item persistence are not one durable
  transaction. Abrupt process loss can leave partial economic outcomes. Normal
  restart persistence tests do not prove crash-atomic payment handling.
- No MySQL, Steam ID LAN, stock-Core or Linux runtime support has been verified.
- Fighting's damage feature is experimental, disabled in public configuration;
  its compiled fallback is still 25. Install the config. Ham configuration validity
  is not proof of correct runtime offsets. Existing CRC warnings remain unresolved.
- ATM detection depends on Apollo NPC internals and proximity; it has no line-of-sight
  requirement. Rewards create wallet money. Cancel/death/disconnect keeps cooldown.
- Different addons can run activities simultaneously; there is no suite-wide action lock.
- Craft thresholds/recipes are partly hardcoded. Missing items vary by installation.
- Job thresholds govern entry through these menus only. Lowering a skill afterward
  does not fire the player. Other admin/job systems can assign independently.
- Law allows the stock `t` flag; operators must review any custom use of this flag.
- Old Stage/Apollo wording remains in some UI text for compatibility with this snapshot.

## Manual release checklist

- [ ] Compile all eight sources with the documented compiler/includes.
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
