/* TSRP SkillWorks | SPDX-License-Identifier: GPL-3.0-or-later
 * Private implementation included ONLY by ARP_Skills.sma.
 * Level + XP + XP cooldown commit atomically in SQLite. Apollo inventory/money
 * are separate: a process crash between item delivery and XP may lose that XP.
 */
#define XP_CREATE "CREATE TABLE IF NOT EXISTS arp_skill_xp (steamid TEXT NOT NULL, skill INTEGER NOT NULL, xp INTEGER NOT NULL DEFAULT 0, last_award INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (steamid,skill))"
#define XP_GET "SELECT xp,last_award FROM arp_skill_xp WHERE steamid='%s' AND skill=%d"
#define XP_PUT "INSERT OR REPLACE INTO arp_skill_xp (steamid,skill,xp,last_award) VALUES ('%s',%d,%d,%d)"
#define LEVEL_PUT "UPDATE arp_skills SET %s=%d WHERE steamid='%s' AND %s=%d"
#define MAX_ACTIVITIES 48
new p_XPEnabled, p_XPBase, p_XPStep, p_XPCooldown, p_XPFullGap, p_XPStopGap, p_XPReward[SKILL_COUNT];
new const g_XPDefaults[SKILL_COUNT][] = {"10", "25", "0", "0", "10", "10", "10"};
new g_ActivityCount;
new g_ActOwner[MAX_ACTIVITIES], g_ActSkill[MAX_ACTIVITIES], g_ActLabel[MAX_ACTIVITIES][64];
new g_ActRequired[MAX_ACTIVITIES], g_ActEnabled[MAX_ACTIVITIES], g_ActModule[MAX_ACTIVITIES];
new g_ActLocal[MAX_ACTIVITIES], g_ActPractice[MAX_ACTIVITIES], g_ActCost[MAX_ACTIVITIES], g_ActSeconds[MAX_ACTIVITIES];
new const g_PracticeHelp[SKILL_COUNT][] = {
    "Complete crafting in /general.", "Successfully hack an ATM in /computers.",
    "Use /learn. Job selection and combat award no XP in this alpha.",
    "Use /learn. Job selection awards no XP in this alpha.",
    "Complete crafting in /weapons.", "Finish a recipe in /cook; buying/using items awards no XP.",
    "Complete crafting in /drugs."
};

public plugin_natives()
{
    register_library("SkillWorks");
    register_native("SW_RegisterActivity", "NativeRegisterActivity");
    register_native("SW_AwardXP", "NativeAwardXP");
}

InitProgression()
{
    p_XPEnabled = register_cvar("arp_skills_xp_enabled", "1");
    p_XPBase = register_cvar("arp_skills_xp_base", "100");
    p_XPStep = register_cvar("arp_skills_xp_step", "5");
    p_XPCooldown = register_cvar("arp_skills_xp_cooldown", "30");
    p_XPFullGap = register_cvar("arp_skills_xp_full_gap", "10");
    p_XPStopGap = register_cvar("arp_skills_xp_stop_gap", "25");
    new name[64];
    for (new i; i < SKILL_COUNT; i++)
    {
        formatex(name, charsmax(name), "arp_skills_xp_reward_%s", g_Keys[i]);
        p_XPReward[i] = register_cvar(name, g_XPDefaults[i]);
    }
}

bool:ExecXP(const sql[])
{
    new Handle:q = RunQuery(sql);
    if (q == Empty_Handle) return false;
    SQL_FreeHandle(q);
    return true;
}

bool:InitXPDatabase()
{
    if (!ExecXP(XP_CREATE)) return false;
    new Handle:q = RunQuery("PRAGMA table_info(arp_skill_xp)");
    if (q == Empty_Handle) return false;
    new const names[][] = {"steamid", "skill", "xp", "last_award"};
    new name[32], kind[32], count, bool:valid = true;
    while (SQL_MoreResults(q))
    {
        SQL_ReadResult(q, 1, name, charsmax(name));
        SQL_ReadResult(q, 2, kind, charsmax(kind));
        if (count >= 4) valid = false;
        else if (!equal(name, names[count]) || !SQL_ReadResult(q, 3)
            || SQL_ReadResult(q, 5) != (count < 2 ? count + 1 : 0)
            || !equali(kind, count == 0 ? "TEXT" : "INTEGER")) valid = false;
        count++;
        SQL_NextRow(q);
    }
    SQL_FreeHandle(q);
    return valid && count == 4;
}

bool:ReadXP(const auth[], skill, &xp, &last)
{
    xp = 0; last = 0;
    new sql[256];
    formatex(sql, charsmax(sql), XP_GET, auth, skill);
    new Handle:q = RunQuery(sql);
    if (q == Empty_Handle) return false;
    if (SQL_NumResults(q)) { xp = SQL_ReadResult(q, 0); last = SQL_ReadResult(q, 1); }
    SQL_FreeHandle(q);
    // Bound corrupted data rather than awarding arbitrary levels or overflowing.
    return xp >= 0 && xp <= 1100000 && last >= 0;
}

bool:WriteXP(const auth[], skill, xp, last)
{
    new sql[256];
    formatex(sql, charsmax(sql), XP_PUT, auth, skill, xp, last);
    return ExecXP(sql);
}

bool:WriteLevel(const auth[], skill, oldValue, value)
{
    new sql[256];
    formatex(sql, charsmax(sql), LEVEL_PUT, g_Keys[skill], value, auth, g_Keys[skill], oldValue);
    new Handle:q = RunQuery(sql);
    if (q == Empty_Handle) return false;
    new affected = SQL_AffectedRows(q);
    SQL_FreeHandle(q);
    return affected == 1;
}

bool:SaveLevel(const auth[], skill, oldValue, value, bool:resetXP)
{
    if (!ExecXP("BEGIN IMMEDIATE")) return false;
    new xp, last;
    if (!ReadXP(auth, skill, xp, last) || !WriteLevel(auth, skill, oldValue, value)
        || !WriteXP(auth, skill, (resetXP || value == SKILL_MAX) ? 0 : xp, last)
        || !ExecXP("COMMIT"))
    { ExecXP("ROLLBACK"); return false; }
    return true;
}

bool:XPCurve(&base, &step)
{
    return SW_ReadInt(p_XPBase, 1, 100000, base) && SW_ReadInt(p_XPStep, 0, 10000, step);
}

bool:XPSettings(skill, &base, &step, &reward, &cooldown, &fullGap, &stopGap)
{
    return XPCurve(base, step) && SW_ReadInt(p_XPReward[skill], 0, 10000, reward)
        && SW_ReadInt(p_XPCooldown, 1, 86400, cooldown)
        && SW_ReadInt(p_XPFullGap, 0, 99, fullGap)
        && SW_ReadInt(p_XPStopGap, 1, 100, stopGap) && stopGap > fullGap;
}

// Deterministic integer arithmetic; at most 100 iterations even with custom rates.
XPReward(level, required, reward, fullGap, stopGap)
{
    new gap = level - required;
    if (gap < 0 || gap >= stopGap || reward == 0) return 0;
    return gap <= fullGap ? reward : max(1, reward / 2);
}
AdvanceXP(&level, &xp, base, step)
{
    while (level < SKILL_MAX && xp >= base + step * level)
    {
        xp -= base + step * level;
        level++;
    }
    if (level == SKILL_MAX) xp = 0;
}

public NativeRegisterActivity(plugin, params)
{
    new skill = get_param(1);
    if (params != 9 || skill < 0 || skill >= SKILL_COUNT || g_ActivityCount >= MAX_ACTIVITIES) return 0;
    new a = g_ActivityCount++;
    g_ActOwner[a] = plugin; g_ActSkill[a] = skill;
    get_string(2, g_ActLabel[a], charsmax(g_ActLabel[]));
    g_ActRequired[a] = get_param(3); g_ActEnabled[a] = get_param(4); g_ActModule[a] = get_param(5);
    g_ActLocal[a] = get_param(6); g_ActPractice[a] = get_param(7);
    g_ActCost[a] = get_param(8); g_ActSeconds[a] = get_param(9);
    return a + 1;
}

bool:ActivitySettings(a, &required)
{
    new unused;
    return SW_Enabled(g_ActEnabled[a]) && SW_Enabled(g_ActModule[a])
        && SW_ReadInt(g_ActRequired[a], 0, 100, required)
        && (!g_ActCost[a] || SW_ReadInt(g_ActCost[a], 0, 1000000, unused))
        && (!g_ActSeconds[a] || SW_ReadInt(g_ActSeconds[a], 1, 3600, unused));
}

bool:ActivityAvailable(a, &required)
{
    if (!ActivitySettings(a, required)) return false;
    new status[16], dummy[2];
    if (get_plugin(g_ActOwner[a], dummy, 1, dummy, 1, dummy, 1, dummy, 1, status, charsmax(status)) < 0) return false;
    if (!equal(status, "running") && !equal(status, "debug")) return false;
    new callback = get_func_id("SW_ActivityAvailable", g_ActOwner[a]);
    if (callback < 0 || callfunc_begin_i(callback, g_ActOwner[a]) != 1) return false;
    callfunc_push_int(g_ActLocal[a]);
    return callfunc_end() != 0;
}

public NativeAwardXP(plugin, params)
{
    new id = get_param(1), a = get_param(2) - 1;
    if (params != 2 || id < 1 || id > 32 || a < 0 || a >= g_ActivityCount
        || g_ActOwner[a] != plugin || !g_ActPractice[a] || !g_Ready || !is_user_alive(id)
        || !SW_Enabled(p_XPEnabled)) return 0;
    new skill = g_ActSkill[a], required;
    // Do not call back into the awarding plugin. It has just validated success.
    if (!ActivitySettings(a, required)) return 0;
    // Study remains the fast, paid route. Do not stack XP during any lesson.
    if (g_Lesson[id]) { client_print(id, print_chat, "[Skills] No practical XP while studying."); return 0; }
    new base, step, reward, cooldown, fullGap, stopGap;
    if (!XPSettings(skill, base, step, reward, cooldown, fullGap, stopGap))
    { client_print(id, print_chat, "[Skills] XP settings invalid. Activity completed without XP."); return 0; }
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(id, values, auth, charsmax(auth))) return XPFailure(id);
    new oldValue = values[skill];
    if (oldValue < 0 || oldValue >= SKILL_MAX) return 0;
    reward = XPReward(oldValue, required, reward, fullGap, stopGap);
    if (!reward) { client_print(id, print_chat, "[Skills] No practical XP: activity too easy or reward disabled."); return 0; }
    if (!ExecXP("BEGIN IMMEDIATE")) return XPFailure(id);
    new xp, last, now = get_systime();
    if (!ReadXP(auth, skill, xp, last)) { ExecXP("ROLLBACK"); return XPFailure(id); }
    // Future timestamps (clock rollback) also fail closed. Cooldown survives maps/reconnects.
    if (last > 0 && (now < last || now - last < cooldown))
    { ExecXP("ROLLBACK"); client_print(id, print_chat, "[Skills] Activity completed; practical XP cooldown active."); return 0; }
    new level = oldValue;
    xp += reward;
    AdvanceXP(level, xp, base, step);
    if (!WriteLevel(auth, skill, oldValue, level) || !WriteXP(auth, skill, xp, now) || !ExecXP("COMMIT"))
    { ExecXP("ROLLBACK"); return XPFailure(id); }
    if (level > oldValue)
        client_print(id, print_chat, "[Skills] +%d %s XP. Level %d -> %d! Progress saved.", reward, g_Labels[skill], oldValue, level);
    else client_print(id, print_chat, "[Skills] +%d %s XP (%d/%d). Saved.", reward, g_Labels[skill], xp, base + step * level);
    return reward;
}
XPFailure(id)
{
    client_print(id, print_chat, "[Skills] Activity completed, but XP save failed. Tell an admin; XP was not credited.");
    return 0;
}

ShowSkillsMenu(id)
{
    if (id < 1 || id > 32) return PLUGIN_HANDLED;
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(id, values, auth, charsmax(auth)))
    { client_print(id, print_chat, "[Skills] Wait for your account or check the server log."); return PLUGIN_HANDLED; }
    DestroyOwnMenu(id);
    new menu = menu_create("SkillWorks | Levels and practical XP", "ChooseSkillDetail");
    g_Menu[id] = menu;
    new label[128], info[8], base, step, xp, last;
    new bool:curve = XPCurve(base, step);
    for (new i; i < SKILL_COUNT; i++)
    {
        num_to_str(i, info, charsmax(info));
        if (values[i] >= SKILL_MAX) formatex(label, charsmax(label), "%s: %d/100 | MAX", g_Labels[i], values[i]);
        else if (curve && ReadXP(auth, i, xp, last))
            formatex(label, charsmax(label), "%s: %d/100 | XP %d/%d", g_Labels[i], values[i], xp, base + step * values[i]);
        else formatex(label, charsmax(label), "%s: %d/100 | XP unavailable", g_Labels[i], values[i]);
        menu_additem(menu, label, info);
    }
    menu_setprop(menu, MPROP_EXITNAME, "Close");
    menu_display(id, menu, 0, 60);
    return PLUGIN_HANDLED;
}

public ChooseSkillDetail(id, menu, item)
{
    if (g_Menu[id] != menu) return PLUGIN_HANDLED;
    g_Menu[id] = -1;
    new info[8], label[128], access, callback, skill = -1;
    if (item >= 0)
    {
        menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback);
        skill = str_to_num(info);
    }
    menu_destroy(menu);
    if (skill < 0 || skill >= SKILL_COUNT) return PLUGIN_HANDLED;
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(id, values, auth, charsmax(auth))) return PLUGIN_HANDLED;
    // Keep under GoldSrc MOTD limits. Current suite has at most six entries per skill.
    new text[1536], pos, xp, last, base, step, reward, cooldown, fullGap, stopGap;
    pos = formatex(text, charsmax(text), "%s | Level %d/100^n", g_Labels[skill], values[skill]);
    if (values[skill] >= SKILL_MAX) pos += formatex(text[pos], charsmax(text)-pos, "Maximum level.^n");
    else if (XPCurve(base, step) && ReadXP(auth, skill, xp, last))
        pos += formatex(text[pos], charsmax(text)-pos, "Practical XP: %d / %d towards next level.^n", xp, base + step * values[skill]);
    else pos += formatex(text[pos], charsmax(text)-pos, "XP unavailable: check database/configuration.^n");
    pos += formatex(text[pos], charsmax(text)-pos, "^n%s^nEducation: /learn (bank payment). Study to reach initial unlocks.^n", g_PracticeHelp[skill]);
    if (!SW_Enabled(p_XPEnabled)) pos += formatex(text[pos], charsmax(text)-pos, "Practical XP disabled.^n");
    else if (XPSettings(skill, base, step, reward, cooldown, fullGap, stopGap))
        pos += formatex(text[pos], charsmax(text)-pos, "XP per success: %d; cooldown %ds per skill.^nFull XP through %d levels above requirement; half until %d; then none.^nNo practical XP while studying.^n", reward, cooldown, fullGap, stopGap-1);
    else pos += formatex(text[pos], charsmax(text)-pos, "Practical XP settings invalid.^n");
    pos += formatex(text[pos], charsmax(text)-pos, "^nSKILL UNLOCKS (other activity requirements still apply)^n");
    new next = -1, nextRequired = 101, count, required;
    for (new a; a < g_ActivityCount; a++)
    {
        if (g_ActSkill[a] != skill) continue;
        count++;
        if (!ActivityAvailable(a, required))
            pos += formatex(text[pos], charsmax(text)-pos, "%s: unavailable/disabled^n", g_ActLabel[a]);
        else
        {
            pos += formatex(text[pos], charsmax(text)-pos, "%s: %s (level %d)^n", g_ActLabel[a], values[skill] >= required ? "UNLOCKED" : "LOCKED", required);
            if (required > values[skill] && required < nextRequired) { nextRequired = required; next = a; }
        }
    }
    if (!count) pos += formatex(text[pos], charsmax(text)-pos, "No activities registered; check addon installation.^n");
    if (next != -1) pos += formatex(text[pos], charsmax(text)-pos, "^nNext: %s at level %d.^n", g_ActLabel[next], nextRequired);
    else pos += formatex(text[pos], charsmax(text)-pos, "^nNo further available unlocks on this server.^n");
    formatex(text[pos], charsmax(text)-pos, "^nClose this panel; /skills returns to the overview.");
    show_motd(id, text, "SkillWorks - Skill details");
    return PLUGIN_HANDLED;
}
