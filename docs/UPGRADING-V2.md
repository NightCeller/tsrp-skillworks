# Upgrade from the working SkillWorks baseline

Candidate: **2.0.0-alpha.1**. Eight modules compiled without warnings; in-game
upgrade testing is pending. This source package is separate from the working
release. No database migration, account reset, new plugin names or map SQL reload.

## Build and install on the Windows test server

1. Stop the server normally and keep a backup of the working plugins, configs and
   saved data. Use a separate test-server copy for the first v2 run.
2. Extract this source ZIP into its own folder. Either use `tools/build.ps1` as
   described in [INSTALL.md](INSTALL.md), or follow the familiar manual compiler route:
   - Copy the eight `addons/amxmodx/scripting/ARP_*.sma` files to your server's
     `addons/amxmodx/scripting` folder.
   - Copy **`addons/amxmodx/scripting/include/SkillWorks_Config.inc`** to your
     server's `addons/amxmodx/scripting/include` folder. This new file is required.
   - Compile those eight sources with your existing AMXX 1.10.0.5487 compiler.
3. With the test server stopped, replace its eight matching `.amxx` files in
   `addons/amxmodx/plugins`. Copying `.sma` files alone does not update loaded plugins.
4. Merge the new settings from the eight example configs into
   `addons/amxmodx/configs/arp`. Preserve your own balancing choices. Keep
   `arp_fighting_bonus_percent 0` while damage testing remains deferred.
5. Keep the same plugin entries/order: Skills first, gameplay addons afterward,
   all after their Apollo dependencies. Do not add duplicate entries.
6. Start the test server. In the **server console**, run `amxx plugins`. All eight
   SkillWorks entries should be running/debug, with no failed plugins. Check:

```text
arp_skills_version
arp_general_version
arp_fighting_bonus_percent
```

Both versions should be `2.0.0-alpha.1`; the damage setting should be `0`.
Version columns in the plugin list can be truncated, so query the cvars.
Confirm your HUD, saved skills, wallet, bank, job and inventory are still present.

## First gameplay check: configurable Flashlight

Use your current General skill and wallet; do not reset the database or progress.
In the **server console**, set:

```text
arp_general_enabled_flashlight 1
arp_general_skill_flashlight 0
arp_general_cost_flashlight 10
arp_general_seconds_flashlight 5
```

In **game chat**, type `/general` (or `arp_general` in the game console).
Flashlight should show **skill 0, $10, 5s**. With at least $10 in your wallet,
confirm crafting. After five seconds, `/items` should contain one additional
Flashlight and your wallet should be exactly $10 lower. Your General skill stays
unchanged. Check the server log for new errors.

Restore the default Flashlight settings in the server console afterward:

```text
arp_general_skill_flashlight 20
arp_general_cost_flashlight 25
arp_general_seconds_flashlight 30
```

If your previous balance was customized, restore those values instead. These
console changes are temporary; the config file takes effect again on map load.
Next checks are disabled recipes, malformed settings and stale confirmations in
[TESTING.md](TESTING.md). Do not label v2 stable until the live checks pass.

## Rollback

Stop normally and restore the previous eight plugin binaries and their configs.
Keep the current database: v2 does not change its schema. Items/money/jobs produced
during testing are ordinary game changes; rollback does not reverse them.
