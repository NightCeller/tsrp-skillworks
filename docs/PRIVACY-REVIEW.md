# Distribution review — 2026-11-04

The package was constructed from an explicit allowlist of eight skill source files
and eight reviewed skill configurations, not by copying the full server and then
trying to delete selected secrets.

Excluded categories: all database/player data, data/vault folders, users.ini,
SQL/connection settings, general server configs, plugin admin settings, logs,
map data, compiled plugins, executables, modules, third-party includes, maps/models/sounds,
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

v2 adds one project-owned include (`SkillWorks_Config.inc`), not any Apollo or AMXX
headers. The source package excludes local build outputs. Its package checks pass;
the private original server archive is not copied into this repository.

V3 adds two more project-owned includes, progression tests and documentation.
The V3 source package uses the same allowlist and excludes compiler outputs,
private server data and the original uploaded archive.
