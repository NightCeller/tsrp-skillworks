# Upgrade to SkillWorks 3.0.0-alpha.1

All eight plugins compiled without warnings with AMXX 1.10.0.5487.
26 automated checks pass; this exact V3 alpha still needs live gameplay checks.
The working V2 files have been kept separately. Nothing has been published.

## Install on your test server

1. Stop normally and back up the entire working server, including its SQLite data,
   plugins and custom configs. Prefer testing a separate server copy.
2. Copy the eight `addons/amxmodx/scripting/ARP_*.sma` files into your scripting
   folder. Copy **all three** files from `scripting/include` into its `include` folder:
   `SkillWorks_Config.inc`, `SkillWorks.inc`, `SkillWorks_Progression.inc`.
3. Compile all eight sources with your existing AMXX compiler and Apollo/TS includes.
   With the server stopped, replace the eight matching `.amxx` files in `plugins`.
   Copying source alone does not install an update. No new plugin entry is needed.
4. Keep your existing V2 gameplay balancing. Add the **V3 practical XP block** from
   the supplied `configs/arp/skills.cfg` to yours. Do not duplicate cvar lines.
   Keep `arp_fighting_bonus_percent 0` in fighting.cfg.
5. Keep Skills before the gameplay addons in plugins.ini, after the Apollo
   dependencies. Start normally. Run `amxx plugins` in the server console and
   verify all eight are running/debug. Query `arp_skills_version` and
   `arp_general_version`: both should report `3.0.0-alpha.1`.
6. Check your existing skill levels, wallet, bank, inventory, job and HUD.
   The new XP table is created automatically; existing levels are not reset.
   **Do not import map SQL, delete tables or copy a database from this package.**

## First test: menu and one Flashlight XP award

Use a test character with General below 100 and at least $10 in the wallet.
Record the current level/XP in `/skills`; leave the detail panel and close menus.
Do not begin a lesson. There is no need to reset your current skill.

In the server console, set these temporary test values. Replace `N` with the
character's current General level, as displayed by `/skills`:

```text
arp_general_enabled 1
arp_general_enabled_flashlight 1
arp_general_skill_flashlight N
arp_general_cost_flashlight 10
arp_general_seconds_flashlight 5
arp_skills_xp_enabled 1
arp_skills_xp_base 100
arp_skills_xp_step 5
arp_skills_xp_reward_general 10
arp_skills_xp_cooldown 30
arp_skills_xp_full_gap 10
arp_skills_xp_stop_gap 25
```

Type `/general` in game chat and complete a Flashlight. Expect one additional
Flashlight, $10 deducted and a **+10 General XP** chat message. `/skills` should
show the saved increase. At General 20, a fresh V3 record shows **10 / 200 XP**.
If enough XP was already present, the level increases and remaining XP carries.
The requirement is set to your current level so the activity is not too easy.

Disconnect/reconnect, then perform a normal full shutdown/restart: confirm the
same level and XP remain. Settings revert to config-file values at restart.
Check for new AMXX errors. Restore your own General/XP settings after testing;
`exec addons/amxmodx/configs/arp/general.cfg` and
`exec addons/amxmodx/configs/arp/skills.cfg` reapply the saved configs.

If your test character is already General 100, use another test character or,
only on a disposable test-server copy, record the current value then use
`arp_skill_set "Specialist" general 20` in game console. Admin set/add commands
clear that skill's partial XP; they are not a harmless way to inspect progress.

## Additional acceptance tests

- Repeat a five-second craft within 30 seconds of the last XP award: item/payment
  still complete but XP does not increase. After 30 seconds a new completion awards.
- Cancel, die or disconnect during a craft: no XP or completed item/payment.
- In the disposable copy, temporarily set XP base=10, step=0, reward_general=10.
  One eligible completion should give exactly one level; restore defaults. Test
  level 99 -> 100 and ensure no XP is stored beyond the cap.
- At level 31 against requirement 20, receive 5 XP. At level 45 against
  requirement 20, receive none. Restore test values afterward.
- Set XP base to `abc`, reward to `-1`, or stop_gap <= full_gap: activity completes
  normally but no XP is awarded. Restore valid values.
- Verify `/skills` reflects changed thresholds, disabled/missing items, paused
  plugins, and jobs missing before setup. Law's stock `t` access remains allowed.
- Earn partial XP then finish paid self-study: level rises, partial XP stays,
  except at level 100 where it clears. No practical XP is awarded during a lesson.
- Complete one Cooking, Weapons and Drugs action, then a successful ATM attempt.
  Check correct skill XP. Failed ATM attempts and job changes award none.
- Validate death/reconnect slot reuse, multiple players, and configuration changes
  during confirmations/actions. V2 activity checks remain applicable.

## Rollback

Stop normally and restore the previous complete eight-plugin set and configs.
The old skill table is unchanged and remains readable by V2; leave the new XP
table in place. Levels, money and inventory earned during testing are not undone.
If you later return to V3, old partial XP remains; V2 cannot maintain or reset it.
Use your pre-test backup for an exact test rollback, accepting that it discards
all later server activity. Do not mix V2 addons with V3 and expect complete XP
or unlock registration.
