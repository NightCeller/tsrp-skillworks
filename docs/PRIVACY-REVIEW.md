# Distribution review — 2026-11-04

The package was constructed from an explicit allowlist of eight skill source files
and eight reviewed skill configurations, not by copying the full server and then
trying to delete selected secrets.

Excluded categories: all database/player data, data/vault folders, users.ini,
SQL/connection settings, general server configs, plugin admin settings, logs,
map data, compiled plugins, executables, modules, includes, maps/models/sounds,
original archives and personal machine paths. Only a standard GPL licence text
was additionally taken from the distribution. No credentials are required to
configure SkillWorks; it uses Apollo's existing connection tuple.

Automated checks scan for forbidden paths/extensions, account/address patterns,
common token/private-key formats and executable configuration commands outside
an allowlist. A separate private comparison checked source/config content against
credential assignments and personal identifiers in the uploaded server archive;
values are not reproduced here. These checks reduce accidental exposure but cannot
guarantee detection of every possible secret. Review each future commit.

The original uploaded archive is unchanged and is not part of this package.
