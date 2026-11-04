/* TSRP SkillWorks | SPDX-License-Identifier: GPL-3.0-or-later */
#if defined _skillworks_api_included
    #endinput
#endif
#define _skillworks_api_included
#define SW_GENERAL 0
#define SW_COMPUTERS 1
#define SW_FIGHTING 2
#define SW_LAW 3
#define SW_WEAPONS 4
#define SW_COOKING 5
#define SW_DRUGS 6

// V3 requires ARP_Skills loaded before its addons. Handles are map-local.
// Owner must implement public SW_ActivityAvailable(localIndex), returning 0/1.
// Register in plugin_cfg. Cvar arguments are pointers returned by register_cvar.
// practice=0 describes job unlocks but cannot award XP.
native SW_RegisterActivity(skill, const label[], required, enabled, moduleEnabled,
    localIndex, practice = 1, cost = 0, seconds = 0);
// Call ONCE, only after successful delivery/payment. Returns saved XP or 0.
// No player console/chat command exposes this native.
native SW_AwardXP(id, activity);
