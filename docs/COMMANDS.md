# Commands

Use slash commands in chat (normal or team). Use console commands in the game console.

| Chat | Console | Purpose |
| --- | --- | --- |
| /skills | arp_skills | Open levels/XP menu and skill details |
| /skillmenu or /learn | arp_skillmenu | Self-study menu; bank payment |
| /educationprices | arp_educationprices | Current lesson prices |
| /cancellearning | arp_learn_cancel | Cancel unfinished lesson |
| /cook | arp_cook | Cooking and ingredient supplies |
| /cancelcook | arp_cook_cancel | Cancel cooking |
| /computers or /hackatm | arp_computers | Attempt nearby Apollo ATM |
| /cancelhack | arp_hack_cancel | Cancel attempt; cooldown remains |
| /weapons | arp_weapons | Weapon inventory crafting |
| /cancelcraft | arp_craft_cancel | Cancel weapon crafting |
| /general | arp_general | Utility crafting |
| /cancelgeneral | arp_general_cancel | Cancel utility crafting |
| /drugs | arp_drugs | Consumable inventory crafting |
| /canceldrugs | arp_drugs_cancel | Cancel consumable crafting |
| /fighting | arp_fighting | Fighting jobs and calculated bonus |
| /law | arp_law | Law jobs |

## Administrator commands

Require the server console or a loaded **Apollo administrator**; AMXX admin alone
is not sufficient. Targets must be online with a loaded authenticated account.

```text
arp_skill_view "PlayerName"
arp_skill_set "PlayerName" general 10
arp_skill_add "PlayerName" general 5
arp_fighting_setup
arp_law_setup
```

Valid skill keys: `general computers fighting law weapons cooking drugs`.
Results outside 0–100 and invalid integer/skill inputs are rejected. Admin skill
edits cancel that player's pending lesson. Job setup creates missing definitions,
not player assignments. Job changes through the menus require confirmation.

V3: `/skills` and `arp_skills` now open the progression overview; select a skill
for XP and live unlocks. `/learn` and `/skillmenu` still open education.
Admin set/add resets partial XP for the edited skill, retaining the XP cooldown.
