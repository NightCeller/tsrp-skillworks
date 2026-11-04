# Installation and builds

## Prepare a working server

Make a normal shutdown backup of your server and SQLite data. Test this alpha on
a separate copy first. Confirm Apollo loads your Steam identity and already saves
money, job and inventory. Do not use this package to repair an unrelated broken
Apollo installation. No database files or connection configuration are supplied.

Build reference: AMXX 1.10.0.5487 with the Apollo includes from upstream commit
`067c9d04d416e4a7d7eedce2d644ebaa8e09b52d`. TS-specific headers such as tsfun.inc
must be installed too. Use your existing AMXX+TS scripting includes. All uploaded
Apollo headers matched that reference; they are not bundled here.

## Compile on Windows

With PowerShell, from this repository:

```powershell
.\tools\build.ps1 -CompilerDir 'C:\tsrp\ts\addons\amxmodx\scripting' -IncludeDir 'C:\tsrp\ts\addons\amxmodx\scripting\include'
```

This compiles the eight sources into `build/plugins`. It does not install them,
change the live server, download dependencies or publish a release. The compiler
must have its companion DLLs in CompilerDir. Alternatively copy the eight `.sma`
files into your working scripting folder **and copy `SkillWorks_Config.inc` into
its `include` folder**, run your normal AMXX compiler and collect
only their newly compiled `.amxx` files. Resolve any compile errors before installation.

For a Linux development machine with a working AMXX compiler and required 32-bit
libraries, run `bash tools/build.sh /path/to/scripting /path/to/scripting/include`.
Linux compilation does not establish Linux game-server compatibility.

## Install

1. Stop the server.
2. Copy the newly compiled eight `.amxx` files into `ts/addons/amxmodx/plugins`.
3. Copy the eight files from `addons/amxmodx/configs/arp` to the same server folder.
   For upgrades, merge settings instead of overwriting your own configuration.
4. Add the entries from `examples/plugins-skillworks.ini` **once**, after Apollo
   and its item/chat/NPC plugins in your active plugin list. Do not enable both
   that example file and duplicate entries elsewhere. Skills must precede its addons.
5. Start the server. Check `amxx plugins`, `amxx modules` and current error logs.
6. For optional job modules, run `arp_fighting_setup` and `arp_law_setup` in the
   **server console** once. Existing exact jobs remain unchanged; missing jobs are
   created through Apollo. Similar names can block creation for manual review.
7. Join with Steam online, wait for Apollo to load your account, then use `/skills`
   in chat or `arp_skills` in the game console. Slash commands belong in chat;
   typing `/skills` directly into the console is not the command syntax.

## Module dependencies

All modules require Core, SQLX/SQLite and the Skills schema. Chat commands require
Apollo TalkArea and its dispatcher. Preserve `ARP_NPCs.amxx` filename for ATM detection.

| Addon | Additional dependency |
| --- | --- |
| Cooking | HungerMod must register Fries, Hamburger and Pizza |
| Computers | Apollo NPCs and an existing ATM using its AtmHandle callback |
| Weapons | TS compatibility plugin registering the exact weapon inventory names |
| General | Items plugin registering utility items; missing individual recipes disabled |
| Drugs | Items plugin registering consumables; missing individual recipes disabled |
| Fighting | Ham Sandwich and TSFun/TSX for the experimental damage hook |
| Law | Apollo jobs API; uses existing Lawyer/City Judge jobs where present |

`ARP_Weapons` and Cooking fail startup if their required outputs are missing.
General/Drugs can continue with a subset, but fail if no recipes are available.
Do not rename unrelated items merely to make a recipe load.

## Settings and upgrades

Configs execute every map load; console-only changes need not survive a restart.
The public example sets `arp_fighting_bonus_percent 0` because damage is untested.
The compiled fallback is also zero in v2. Confirm the cvar reads 0 after startup
before combat testing; an older server config can still explicitly enable it.

Retain source, configs and dependency versions alongside backups. All eight plugin versions
now match the repository candidate `2.0.0-alpha.1`. Read [v2 upgrade steps](UPGRADING-V2.md).
No skill schema migration is needed for this update. The core Skills
plugin refuses an incompatible existing schema rather than repairing it.

## Uninstall / rollback

Comment the SkillWorks plugin entries and restart, or restore your known-working
compiled plugins and configs. Do not delete SQLite data. Stored skills, cooldowns,
created jobs and existing job assignments remain; disabling an addon does not
reverse prior transactions or fire players. Restore backups only deliberately.
