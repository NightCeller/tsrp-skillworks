# v2 configuration reference

Edit `addons/amxmodx/configs/arp/<module>.cfg`. Each module executes its own file
on map load. For immediate testing, enter a cvar and value in the **server console**;
save deliberate changes in the file to retain them across full restarts.
Do not put settings in a player's game console or import map SQL for this update.

Values are decimal whole numbers. Outer whitespace is ignored; empty values,
signs, fractions, embedded text and oversized numbers are rejected. Leading zeros
are allowed. Invalid values block the affected action instead of silently becoming
zero. A switch accepts only 0 or 1. Explicit zero costs are permitted.

## Crafting

`module` is `cooking`, `weapons`, `general` or `drugs`. Replace `key` using the table.

| Cvar pattern | Bounds | Meaning |
| --- | --- | --- |
| `arp_<module>_enabled` | 0 or 1 | Whole module switch |
| `arp_<module>_enabled_<key>` | 0 or 1 | Individual recipe switch |
| `arp_<module>_skill_<key>` | 0..100 | Minimum saved skill |
| `arp_<module>_seconds_<key>` | 1..3600 | Duration in seconds |
| `arp_<module>_cost_<key>` | 0..1000000 | Wallet cost; Cooking buys one pack |
| `arp_cooking_supplies` | 0 or 1 | Built-in ingredient pack shop |

| Module | Recipe keys |
| --- | --- |
| Cooking | `fries`, `hamburger`, `pizza` |
| Weapons | `ruger`, `glock`, `fiveseven`, `m4a1`, `ak47`, `berettas` |
| General | `flashlight`, `tape`, `lockpick`, `electric` |
| Drugs | `cigarette`, `cigar`, `acid`, `cocaine` |

Example: set Flashlight to General 25, $40 and 10 seconds:

```cfg
arp_general_enabled_flashlight 1
arp_general_skill_flashlight 25
arp_general_cost_flashlight 40
arp_general_seconds_flashlight 10
```

Default balances are listed in [GAMEPLAY.md](GAMEPLAY.md). No new recipe outputs
or ingredient types can be defined through these cvars. Item effects still belong
to Apollo. Enabling a recipe does not create a missing Apollo item.

Cooking charges when buying a pack; cooking itself consumes that pack at completion.
A disabled Cooking recipe also blocks its pack shop entry. A malformed pack price
blocks purchase, but does not prevent cooking a pack already owned.

## Jobs and fighting

| Cvar | Bounds | Default |
| --- | --- | --- |
| `arp_fighting_enabled` | 0 or 1 | 1 |
| `arp_fighting_jobs` | 0 or 1 | 1 |
| `arp_fighting_job_skill` | 0..100 | 16 |
| `arp_law_enabled` | 0 or 1 | 1 |
| `arp_law_job_skill` | 0..100 | 21 |
| `arp_fighting_bonus_percent` | 0..25, whole numbers | 0 |
| `arp_fighting_debug` | 0 or 1 | 0 |

Thresholds govern choosing a job through these menus. They do not fire existing
workers or change salaries/access. Experimental unarmed damage remains untested;
its maximum percentage now accepts integers only. Effective per-player bonuses
can still be fractional, e.g. 25% maximum at skill 50 calculates 12.5%.

## Existing study and ATM settings

The names/defaults in skills.cfg and computers.cfg are retained. Their numeric
settings now use the same strict reader.

| Setting | Bounds |
| --- | --- |
| Study cost per skill | 0..1000000 |
| Study seconds | 1..3600 |
| Study points | 1..100, capped by remaining skill capacity |
| ATM skill | 0..100 |
| ATM seconds | 1..3600 |
| ATM cooldown | 1..604800 |
| ATM reward minimum/maximum | 0..100000, minimum <= maximum |
| ATM success chance minimum/maximum | 0..100, minimum <= maximum |
| ATM minimum police | 0..32 |
| ATM radius | 30..150 game units |
| Learning/ATM enablement and alerts | 0 or 1 |

## Changes during menus or activities

- Craft confirmations recheck cost, duration, threshold and enablement. Study
  confirmations recheck price, duration and configured points. Job confirmations
  recheck salary, skill requirement and the existing access restrictions.
- An active craft or study cancels on the next one-second check when its relevant
  settings change, become invalid, or the action is disabled. No completion charge,
  item, skill gain or ingredient use occurs. Death/disconnect/cancellation rules remain.
- ATM attempts cancel when their settings change or become invalid. No reward;
  the cooldown recorded at the start remains in place.
- Cooking pack purchases recheck the displayed price. Changing pack prices or the
  supplies-shop switch does not interrupt a cook using an already-owned pack.
- Changing an unrelated recipe does not cancel a player's current craft.
- Settings are compared at action checkpoints; a change reverted before the next
  check is not recorded as a separate event. This is not a configuration history system.
- A full server restart cancels unfinished activities. Existing saved skills,
  money, inventory and job data use the same storage as before.

These checks do not make separate Apollo and Skills writes crash-atomic. Test
operator changes on a server copy before applying them to an active public game.
