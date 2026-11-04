# Gameplay and default configuration

Seven skills range from 0 to 100. All unlock checks use saved skill values.
There are no automatic gains from crafting, damage or taking a job.
Self-study is available anywhere while alive with an authenticated loaded account.
All prices below are game currency; they are not real-world purchases.

## Study — BANK payment

Default lesson: 30 seconds, +1 point, maximum skill 100. Cancel/death/disconnect
before completion does not charge. Bank payment occurs after the skill write;
these are not crash-atomic. Near the cap, a smaller gain still costs the full price.

| Skill | Cost per lesson |
| --- | --- |
| General | $100 |
| Computers | $250 |
| Fighting | $250 |
| Law | $300 |
| Weapons | $300 |
| Cooking | $150 |
| Drugs | $200 |

`skills.cfg` controls learning enablement, duration, gain and each cost. Wallet
money does not pay for lessons. Teacher-led education is not implemented.

## Cooking — ingredient packs bought with WALLET money

| Output | Skill | Pack price | Cooking time |
| --- | --- | --- | --- |
| Fries | 10 | $10 | 30s |
| Hamburger | 10 | $35 | 60s |
| Pizza | 20 | $25 | 60s |

Buy the matching pack in /cook, then cook. One pack is consumed at successful
completion for one food item. Cancellation does not consume it. The food effect
belongs to Apollo HungerMod. Prices/thresholds/times are source constants in this
version; cooking.cfg toggles cooking and the built-in pack shop only.

## Computers — ATM attempts

Default skill 31, duration 60s, reward $50–$150 to WALLET on success. Chance scales
from 50% at skill 31 to 90% at 100. Player and ATM are locked until the scheduled
finish plus 300s; cancellation retains both cooldowns. Player keys use Steam ID;
ATM keys use map and rounded coordinates. No player bank account is robbed.

Stand within 100 game units of an existing Apollo ATM and remain there. The example
allows zero police for solo testing and alerts online Apollo police. Review min-cops,
reward and cooldown settings in computers.cfg before public-server balancing.

## Weapons — WALLET payment at completion

| Output | Skill | Cost | Time |
| --- | --- | --- | --- |
| Ruger MK1 | 35 | $50 | 60s |
| GLOCK-18 | 35 | $50 | 60s |
| FN Five-seveN Tactical | 35 | $100 | 60s |
| Colt M4A1 | 50 | $150 | 120s |
| Kalashnikova AK-47 | 50 | $175 | 120s |
| Akimbo Beretta 92Fs | 50 | $100 | 90s |

Outputs are existing Apollo inventory items. Equipping/using them is handled by
Apollo TS compatibility. Prices and times are configurable in weapons.cfg;
thresholds and output names are source constants. Cancellation is free.

## General — WALLET payment at completion

| Output | Skill | Cost | Time |
| --- | --- | --- | --- |
| Flashlight | 20 | $25 | 30s |
| Tape | 20 | $1 | 30s |
| Lockpick | 40 | $100 | 60s |
| Electric Lockpick | 60 | $250 | 90s |

Missing items appear unavailable. Tape was absent on the maintainer's installation;
its absence does not prevent other recipes. Item effects belong to Apollo Items.
Prices and times are configurable in general.cfg. Cancellation is free.

## Drugs — fictional game inventory only

| Output | Skill | Wallet cost | Time |
| --- | --- | --- | --- |
| Cigarette | 11 | $5 | 40s |
| Cuban Cigar | 16 | $10 | 60s |
| Acid | 21 | $35 | 40s |
| Cocaine | 31 | $75 | 90s |

The addon creates existing consumable inventory items; it adds no new real-world
procedures or item effects. Missing outputs are unavailable. Costs/times are in
drugs.cfg; cancellation is free and payment occurs at completion.

## Fighting and Law — job entry

| Skill | Requirement | Jobs | Setup defaults |
| --- | --- | --- | --- |
| Fighting | 16 | Dojo Worker; Fighter | $20/hr; $30/hr; no access flags |
| Law | 21 | Lawyer; Jury; City Judge | $20/hr; $20/hr; $30/hr; stock t flag |

Setup commands preserve existing jobs/salaries. Menus replace the current job only
after confirmation and another skill check. No fee, automatic promotion or skill
gain. No automatic dismissal when a skill is subsequently lowered. Law adds no
court, arrest, sentencing or bail mechanics. Fighting jobs refuse any access flags;
Law accepts stock t or no flags, rejects extra flags and configured admin access.

Fighting also implements an experimental bonus, disabled in the public config.
If enabled at 25, skill 16 calculates +4%, 50 +12.5%, and 100 +25%. It only targets
direct unarmed player damage with TS weapon 36; armed kicks do not qualify.
Actual classification and effects are untested. See TESTING.md before enabling.
