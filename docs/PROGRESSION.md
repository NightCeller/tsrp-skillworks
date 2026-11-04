# Practical progression — V3 alpha

## Defaults

| Setting | Default | Valid range / meaning |
| --- | ---: | --- |
| arp_skills_xp_enabled | 1 | 0 or 1; does not disable paid study |
| arp_skills_xp_base | 100 | 1–100000 |
| arp_skills_xp_step | 5 | 0–10000 |
| arp_skills_xp_cooldown | 30 | 1–86400 seconds per player and skill |
| arp_skills_xp_full_gap | 10 | 0–99 levels above the activity requirement |
| arp_skills_xp_stop_gap | 25 | 1–100; must exceed full_gap |
| arp_skills_xp_reward_general | 10 | 0–10000 per successful craft |
| arp_skills_xp_reward_cooking | 10 | 0–10000 per finished recipe, not pack purchase |
| arp_skills_xp_reward_weapons | 10 | 0–10000 per successful craft |
| arp_skills_xp_reward_drugs | 10 | 0–10000 per successful craft |
| arp_skills_xp_reward_computers | 25 | 0–10000 per successful ATM payout |
| arp_skills_xp_reward_fighting | 0 | Reserved; no practical award hooks in V3 alpha |
| arp_skills_xp_reward_law | 0 | Reserved; no practical award hooks in V3 alpha |

Next-level XP is `base + step * current_level`. At General 20 the default is 200:
20 full-reward crafts for one level. Paid study remains faster and uses bank money.
Existing skills start with zero partial XP on first V3 use; no retroactive awards.

At up to 10 levels above the activity requirement, get the full reward. From 11
through 24 above, get half, rounded down (minimum 1 if reward is positive). At 25
above, or below the requirement, get none. Level 100 stores no further XP.
Costs/times/requirements still come from the V2 module configs.

## Transaction and lifecycle rules

- Only the owning addon can award against its registered activity handle. No
  public player command awards XP. Job registrations are not eligible to award.
- Addons call once after verified item delivery/payment or ATM payout, after
  clearing their running flag. Failure/cancellation/consumable use has no hook.
- XP cooldowns persist by Steam ID and skill, so another recipe, reconnect, map
  change or restart cannot reset them. ATM cooldowns apply separately as before.
  A clock moving backwards suppresses XP until the saved timestamp is passed.
- Synchronous local SQLite transactions write level, partial XP and timestamp
  together. No per-slot XP cache and no disconnect-delayed writes. XP/level errors
  roll back together and are reported; completed item/payment is not undone.
- Paid study keeps partial XP, except at 100. Admin set/add clears that skill's XP
  but preserves its XP cooldown. No practical XP during any active study lesson.
- XP settings are read at completion. Changing the curve does not convert stored
  XP immediately: conversion occurs on the next eligible successful award. A
  lowered curve can produce several levels at that time, capped at 100.
- Invalid XP settings disable awards while leaving valid economic actions intact.
  The enable switch, maximum level and cooldown can suppress an award. The detail
  panel explains general XP rules; it does not promise XP on every completion.
- Public defaults still need economic/multiplayer balancing. Simultaneous actions
  in different modules remain possible; this is not a suite-wide action lock.

## Menu and integration

`/skills` (or `arp_skills`) lists seven skills and partial XP. Selecting one opens
an engine MOTD details panel with available/locked abilities and next unlock.
Use `/skills` again to return. `/skillmenu` and `/learn` remain education menus.
Admin `arp_skill_view` remains a level-only console command.

The menu reads live cvar pointers and calls each loaded addon's availability
callback. Missing items/jobs, invalid settings and paused modules are unavailable.
"UNLOCKED" means the skill requirement is met, not that funds, ingredients,
police count, proximity, cooldowns or other action requirements are satisfied.
There is no registered ability for Fighting's experimental damage bonus.

`SkillWorks.inc` declares the V3 activity registry and XP natives. The private
`SkillWorks_Progression.inc` is compiled only through ARP_Skills. Addons still read
levels using their established SQLite queries; a full replacement skill-read API
is outside this alpha. Upgrade all eight plugins together.
