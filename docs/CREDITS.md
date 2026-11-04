# Credits and provenance

- **NightCeller** — project maintenance, server integration and reported gameplay testing.
- **Apollo RP team / Douglas Sherk** — roleplay framework and APIs:
  https://github.com/DouglasSherk/Apollo-RP
- **AMX Mod X / AlliedModders contributors** — compiler, runtime and modules:
  https://www.amxmodx.org/
- **Harbu RP / HarbuRPSkillMod authors** — historical design reference for seven
  skill categories, study prices and selected job/recipe thresholds. This is an
  Apollo-native implementation, not the original Harbu plugin or an exact restoration.
- **The Specialists team, Valve and Metamod contributors** — underlying game/platform.

The source snapshot supplied by the maintainer on 2026-11-04 matches the eight
latest addon sources developed during this project. `source-manifest.json`
records original source hashes, without personal account data. Repository edits
add project/licence comments and normalize line endings; gameplay code is unchanged.
Some in-game text still uses historical Apollo/Stage labels. Branding cleanup is
tracked on the roadmap rather than silently changing the tested binaries.

All uploaded ApolloRP include files matched upstream commit
`067c9d04d416e4a7d7eedce2d644ebaa8e09b52d` after normalizing line endings.
The uploaded patched Core SHA-256 was
`ab0fa07a8e6c209d4c175ba09596b2fec1e31eeb6c55123e7d1be8db46778b2a`.
These identify the comparison/test environment; they are not guarantees of stock
Core compatibility. Core and include files remain external dependencies.

The AMXX licence notice included with the supplied distribution specifies GPL
version 3 or later and a Half-Life linking exception. Upstream reference:
https://github.com/alliedmodders/amxmodx/blob/master/public/licenses/LICENSE.txt
The unmodified GPLv3 licence text is included as LICENSE. This project adopts
GPL-3.0-or-later plus the documented linking permission for its own files; it does
not relicense third-party code. No Harbu source, map, model, sound, or commercial
server/game component is included.
