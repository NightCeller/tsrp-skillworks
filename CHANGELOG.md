# Changelog

## 0.1.0-alpha.1 — release candidate, 2026-11-04

First independent source package; not yet published to GitHub.

- Collected eight matching server-tested source snapshots and reviewed configurations.
- Added installation/build scripts, command/default documentation, contribution
  guidance, issue templates, source-only CI and distribution checks.
- Added project/licence comments without changing gameplay code or plugin versions.
- Public Fighting configuration disables untested bonus (uploaded config had 25).
- Corrected stale config comments for Skills and General.
- Excluded databases, logs, admin users, credentials, map data, binaries and assets.

### Development milestones included

- Skills 0.2.1: seven persisted skill values, administrator commands, paid self-study
  and Apollo chat registration.
- Cooking 0.3.0: ingredient inventory and food crafting.
- Computers 0.4.0: ATM gameplay and persistent player/ATM cooldowns.
- Weapons 0.5.0: inventory weapon crafting.
- General 0.6.1: utility crafting; unavailable individual items no longer fail all recipes.
- Drugs 0.7.0: consumable inventory crafting.
- Fighting 0.8.0: jobs and experimental capped unarmed bonus.
- Law 0.9.0: legal job selection; reconnect/full restart persistence confirmed.

See docs/TESTING.md for the distinction between reported gameplay and pending checks.
