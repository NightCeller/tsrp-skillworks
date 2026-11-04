/*
 * TSRP SkillWorks — independent community project maintained by NightCeller.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE and NOTICE for terms and the Half-Life linking exception.
 */
/*
 * Apollo RP Skills - Stage 2 self-study, version 0.2.1
 * New Apollo-native implementation; Harbu's seven categories are the design reference.
 * Requires Apollo RP and AMXX 1.10 SQLX/SQLite. No Harbu plugin is required.
 *
 * CONFIGURATION: all seven skills start at 0, with a stage-one range of 0..100.
 * Change SKILL_MAX before compiling if a different scale is deliberately chosen.
 * Self-study configuration: addons/amxmodx/configs/arp/skills.cfg.
 * No passive gains, crafting, teacher offers, damage modifiers or HUD hooks yet.
 * Lesson payments use Apollo bank APIs on successful completion. Skills commit
 * immediately; bank persistence follows Core. These are NOT one crash-atomic
 * transaction: abrupt process loss can preserve a point before Core saves payment.
 *
 * STORAGE: arp_skills in Apollo's existing SQLite database, keyed by Steam ID.
 * Small synchronous local queries deliberately avoid deferred writes and slot-reuse
 * races. A successful command means SQLite completed the write. No disconnect-time
 * cache exists. Revisit this approach before introducing frequent automatic XP.
 * The plugin owns its SQL connection, never Apollo's shared connection tuple.
 * Existing incompatible schemas cause initialization failure, never automatic repair.
 */
#include <amxmodx>
#include <amxmisc>
#include <ApolloRP>
#include <ApolloRP_Chat>

#define VERSION "0.2.1"
#define SKILL_COUNT 7
#define SKILL_MAX 100

new const g_Keys[SKILL_COUNT][] = {
    "general", "computers", "fighting", "law", "weapons", "cooking", "drugs"
};
new const g_Labels[SKILL_COUNT][] = {
    "General", "Computers", "Fighting", "Law", "Weapons", "Cooking", "Drugs"
};
new Handle:g_Db = Empty_Handle;
new bool:g_Ready;
#define LESSON_TICK 762014
new p_LearnEnabled, p_LearnSeconds, p_LearnGain, p_LearnCost[SKILL_COUNT];
new const g_DefaultCost[SKILL_COUNT][] = {"100", "250", "250", "300", "300", "150", "200"};
new g_Menu[33] = {-1, ...};
new g_QuoteSkill[33], g_QuoteValue[33], g_QuotePrice[33], g_QuoteGain[33], g_QuoteSeconds[33];
new g_Lesson[33]; // zero = inactive; otherwise skill index + 1
new g_LessonValue[33], g_LessonPrice[33], g_LessonGain[33], g_LessonUserid[33];
new g_LessonAuth[33][36];
new Float:g_LessonEnd[33];

public plugin_init()
{
    register_cvar("arp_skills_version", VERSION, FCVAR_SERVER);
    register_clcmd("arp_skills", "CmdSkills");
    register_concmd("arp_skill_set", "CmdChange");
    register_concmd("arp_skill_add", "CmdChange");
    register_concmd("arp_skill_view", "CmdView");
    register_clcmd("arp_skillmenu", "CmdLearn");
    register_clcmd("arp_learn_cancel", "CmdCancelLesson");
    register_clcmd("arp_educationprices", "CmdPrices");
    p_LearnEnabled = register_cvar("arp_skills_learning", "1");
    p_LearnSeconds = register_cvar("arp_skills_lesson_seconds", "30");
    p_LearnGain = register_cvar("arp_skills_lesson_points", "1");
    new cvarName[64];
    for (new i; i < SKILL_COUNT; i++)
    {
        formatex(cvarName, charsmax(cvarName), "arp_skills_cost_%s", g_Keys[i]);
        p_LearnCost[i] = register_cvar(cvarName, g_DefaultCost[i]);
    }
    register_event("DeathMsg", "OnDeath", "a");
    set_task(1.0, "LessonTick", LESSON_TICK, "", 0, "b");
}

public ARP_Init()
{
    ARP_RegisterPlugin("Skills", VERSION, "TSRP Server", "Persistent skills and paid self-study");
    // TalkArea owns say/say_team; register with its dispatcher.
    ARP_RegisterChat("/skills", "ChatSkills", "Shows your saved skill values");
    ARP_RegisterTeamChat("/skills", "ChatSkills", "Shows your saved skill values");
    ARP_RegisterChat("/skillmenu", "ChatSkillMenu", "Study a skill using your bank balance");
    ARP_RegisterTeamChat("/skillmenu", "ChatSkillMenu", "Study a skill using your bank balance");
    ARP_RegisterChat("/learn", "ChatLearn", "Open the self-study menu");
    ARP_RegisterTeamChat("/learn", "ChatLearn", "Open the self-study menu");
    ARP_RegisterChat("/cancellearning", "ChatCancel", "Cancel your unfinished lesson without payment");
    ARP_RegisterTeamChat("/cancellearning", "ChatCancel", "Cancel your unfinished lesson without payment");
    ARP_RegisterChat("/educationprices", "ChatPrices", "View current self-study prices");
    ARP_RegisterTeamChat("/educationprices", "ChatPrices", "View current self-study prices");
    if (ARP_SqlMode() != SQLITE)
    {
        set_fail_state("ARP Skills requires Apollo SQLite mode.");
        return;
    }
    if (!SQL_SetAffinity("sqlite"))
    {
        set_fail_state("Could not select SQLX SQLite driver.");
        return;
    }
    new Handle:tuple = ARP_SqlHandle();
    if (tuple == Empty_Handle)
    {
        set_fail_state("Apollo database tuple is unavailable.");
        return;
    }
    new error[256], code;
    g_Db = SQL_Connect(tuple, code, error, charsmax(error));
    if (g_Db == Empty_Handle)
    {
        log_amx("Skills database connection failed (%d): %s", code, error);
        set_fail_state("Could not connect to Apollo SQLite database.");
        return;
    }
    new Handle:q = RunQuery("CREATE TABLE IF NOT EXISTS arp_skills (steamid TEXT PRIMARY KEY NOT NULL, general INTEGER NOT NULL DEFAULT 0, computers INTEGER NOT NULL DEFAULT 0, fighting INTEGER NOT NULL DEFAULT 0, law INTEGER NOT NULL DEFAULT 0, weapons INTEGER NOT NULL DEFAULT 0, cooking INTEGER NOT NULL DEFAULT 0, drugs INTEGER NOT NULL DEFAULT 0)");
    if (q == Empty_Handle)
    {
        set_fail_state("Could not create arp_skills; see AMXX log.");
        return;
    }
    SQL_FreeHandle(q);
    // Validate names, types, required fields and primary key before any player writes.
    q = RunQuery("PRAGMA table_info(arp_skills)");
    if (q == Empty_Handle)
    {
        set_fail_state("Could not inspect arp_skills schema.");
        return;
    }
    new count, name[32], kind[32], bool:valid = true;
    while (SQL_MoreResults(q))
    {
        SQL_ReadResult(q, 1, name, charsmax(name));
        SQL_ReadResult(q, 2, kind, charsmax(kind));
        if (count == 0)
        {
            if (!equal(name, "steamid") || !equali(kind, "TEXT") || SQL_ReadResult(q, 5) != 1)
                valid = false;
        }
        else if (count <= SKILL_COUNT)
        {
            if (!equal(name, g_Keys[count - 1]) || !equali(kind, "INTEGER") || !SQL_ReadResult(q, 3))
                valid = false;
        }
        else valid = false;
        count++;
        SQL_NextRow(q);
    }
    SQL_FreeHandle(q);
    if (!valid || count != SKILL_COUNT + 1)
    {
        set_fail_state("Existing arp_skills schema is incompatible. No player data was changed.");
        return;
    }
    g_Ready = true;
    log_amx("ARP Skills %s ready: SQLite arp_skills, seven skills, range 0..%d.", VERSION, SKILL_MAX);
}

public ARP_Error(const reason[])
{
    g_Ready = false;
    log_amx("Apollo unavailable: %s", reason);
}

public plugin_end()
{
    remove_task(LESSON_TICK);
    for (new id = 1; id <= 32; id++) DestroyOwnMenu(id);
    if (g_Db != Empty_Handle) SQL_FreeHandle(g_Db);
}

Handle:RunQuery(const statement[])
{
    new Handle:q = SQL_PrepareQuery(g_Db, "%s", statement);
    if (q == Empty_Handle) return Empty_Handle;
    if (!SQL_Execute(q))
    {
        new error[256];
        SQL_QueryError(q, error, charsmax(error));
        log_amx("Skills SQL error: %s", error);
        SQL_FreeHandle(q);
        return Empty_Handle;
    }
    return q;
}

bool:PlayerIdentity(id, auth[], len)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id)) return false;
    if (!ARP_PlayerReady(id)) return false;
    get_user_authid(id, auth, len);
    // Accept authenticated Steam IDs only; also makes SQL interpolation safe.
    if (containi(auth, "STEAM_") != 0 || strlen(auth) < 11) return false;
    new colons;
    for (new i = 6; auth[i]; i++)
    {
        if (auth[i] == ':') colons++;
        else if (auth[i] < '0' || auth[i] > '9') return false;
    }
    return colons == 2;
}

bool:LoadSkills(id, values[SKILL_COUNT], auth[], len)
{
    if (!g_Ready || !PlayerIdentity(id, auth, len)) return false;
    new sql[512];
    formatex(sql, charsmax(sql), "INSERT OR IGNORE INTO arp_skills (steamid) VALUES ('%s')", auth);
    new Handle:q = RunQuery(sql);
    if (q == Empty_Handle) return false;
    SQL_FreeHandle(q);
    formatex(sql, charsmax(sql), "SELECT general,computers,fighting,law,weapons,cooking,drugs FROM arp_skills WHERE steamid='%s'", auth);
    q = RunQuery(sql);
    if (q == Empty_Handle) return false;
    if (!SQL_NumResults(q))
    {
        SQL_FreeHandle(q);
        return false;
    }
    for (new i; i < SKILL_COUNT; i++) values[i] = SQL_ReadResult(q, i);
    SQL_FreeHandle(q);
    return true;
}

// Signature required by TalkArea: player, chat mode, full message.
public ChatSkills(id, mode, const message[])
{
    return CmdSkills(id);
}

public CmdSkills(id)
{
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(id, values, auth, charsmax(auth)))
    {
        client_print(id, print_chat, "[Skills] Unavailable: wait for your Apollo account to load, or check the server log.");
        return PLUGIN_HANDLED;
    }
    new text[1024], pos;
    pos = formatex(text, charsmax(text), "YOUR SKILLS - Stage 2^n^n");
    for (new i; i < SKILL_COUNT; i++)
        pos += formatex(text[pos], charsmax(text) - pos, "%s: %d / %d^n", g_Labels[i], values[i], SKILL_MAX);
    formatex(text[pos], charsmax(text) - pos, "^nProgress is saved to your Steam ID.^nType /skillmenu to study. Skill effects and crafting come later.");
    show_motd(id, text, "Apollo RP Skills");
    return PLUGIN_HANDLED;
}

bool:AdminAllowed(id)
{
    if (!id) return true; // Dedicated-server console.
    if (ARP_PlayerReady(id) && ARP_AdminAccess(id)) return true;
    console_print(id, "[Skills] Apollo administrator access required.");
    return false;
}

public CmdView(id)
{
    if (!AdminAllowed(id)) return PLUGIN_HANDLED;
    if (read_argc() != 2)
    {
        console_print(id, "Usage: arp_skill_view <name/#userid>");
        return PLUGIN_HANDLED;
    }
    new arg[32];
    read_argv(1, arg, charsmax(arg));
    new target = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
    if (!target) return PLUGIN_HANDLED;
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(target, values, auth, charsmax(auth)))
    {
        console_print(id, "[Skills] Target account or database is not ready.");
        return PLUGIN_HANDLED;
    }
    console_print(id, "[Skills] %s", auth);
    for (new i; i < SKILL_COUNT; i++)
        console_print(id, "%s: %d / %d", g_Labels[i], values[i], SKILL_MAX);
    return PLUGIN_HANDLED;
}

public CmdChange(id)
{
    if (!AdminAllowed(id)) return PLUGIN_HANDLED;
    new command[32];
    read_argv(0, command, charsmax(command));
    if (read_argc() != 4)
    {
        console_print(id, "Usage: %s <name/#userid> <skill> <integer>", command);
        console_print(id, "Skills: general computers fighting law weapons cooking drugs");
        return PLUGIN_HANDLED;
    }
    new arg[32], key[32], raw[32];
    read_argv(1, arg, charsmax(arg));
    read_argv(2, key, charsmax(key));
    read_argv(3, raw, charsmax(raw));
    new skill = -1;
    for (new i; i < SKILL_COUNT; i++) if (equali(key, g_Keys[i])) skill = i;
    if (skill == -1)
    {
        console_print(id, "[Skills] Unknown skill. Use general computers fighting law weapons cooking drugs.");
        return PLUGIN_HANDLED;
    }
    new start = (raw[0] == '-' || raw[0] == '+') ? 1 : 0;
    new bool:valid = strlen(raw) > start && strlen(raw) <= 5;
    for (new i = start; raw[i]; i++) if (raw[i] < '0' || raw[i] > '9') valid = false;
    if (!valid)
    {
        console_print(id, "[Skills] Supply a whole number, for example 10 or -5.");
        return PLUGIN_HANDLED;
    }
    new amount = str_to_num(raw);
    new target = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
    if (!target) return PLUGIN_HANDLED;
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(target, values, auth, charsmax(auth)))
    {
        console_print(id, "[Skills] Target account or database is not ready; no skill changed.");
        return PLUGIN_HANDLED;
    }
    new value = equal(command, "arp_skill_add") ? values[skill] + amount : amount;
    if (value < 0 || value > SKILL_MAX)
    {
        console_print(id, "[Skills] Result must be within 0..%d; no skill changed.", SKILL_MAX);
        return PLUGIN_HANDLED;
    }
    new sql[256];
    formatex(sql, charsmax(sql), "UPDATE arp_skills SET %s=%d WHERE steamid='%s'", g_Keys[skill], value, auth);
    new Handle:q = RunQuery(sql);
    if (q == Empty_Handle)
    {
        console_print(id, "[Skills] Save failed; see server log.");
        return PLUGIN_HANDLED;
    }
    SQL_FreeHandle(q);
    // Admin edits cancel a pending quote/lesson so it cannot overwrite new values.
    CancelLesson(target, true);
    DestroyOwnMenu(target);
    new actor[36];
    if (id) get_user_authid(id, actor, charsmax(actor));
    else copy(actor, charsmax(actor), "SERVER");
    log_amx("Admin %s changed %s skill %s from %d to %d", actor, auth, g_Keys[skill], values[skill], value);
    console_print(id, "[Skills] Saved %s: %s = %d", auth, g_Labels[skill], value);
    client_print(target, print_chat, "[Skills] Your %s skill is now %d (saved).", g_Labels[skill], value);
    return PLUGIN_HANDLED;
}

public plugin_cfg()
{
    new path[192], configdir[128];
    get_configsdir(configdir, charsmax(configdir));
    formatex(path, charsmax(path), "%s/arp/skills.cfg", configdir);
    if (file_exists(path)) server_cmd("exec ^"%s^"", path);
    else log_amx("No arp/skills.cfg; using registered education defaults.");
}

// Apollo keys registrations by plugin and handler, so aliases need unique handlers.
public ChatSkillMenu(id, mode, const message[]) { return CmdLearn(id); }
public ChatLearn(id, mode, const message[]) { return CmdLearn(id); }
public ChatCancel(id, mode, const message[]) { return CmdCancelLesson(id); }
public ChatPrices(id, mode, const message[]) { return CmdPrices(id); }

// Destroy only this plugin's menus. Clear the handle first because menu_destroy
// can call a menu handler recursively with MENU_EXIT.
DestroyOwnMenu(id)
{
    new menu = g_Menu[id];
    g_Menu[id] = -1;
    if (menu != -1) menu_destroy(menu);
}

public client_disconnected(id)
{
    CancelLesson(id, false);
    DestroyOwnMenu(id);
}

public client_putinserver(id)
{
    CancelLesson(id, false);
    DestroyOwnMenu(id);
}

public OnDeath()
{
    new id = read_data(2);
    if (id < 1 || id > 32) return;
    CancelLesson(id, true);
    DestroyOwnMenu(id);
}

CancelLesson(id, bool:notify)
{
    new wasActive = g_Lesson[id];
    g_Lesson[id] = 0;
    g_LessonEnd[id] = 0.0;
    g_LessonUserid[id] = 0;
    g_LessonAuth[id][0] = 0;
    if (notify && wasActive && is_user_connected(id))
        client_print(id, print_chat, "[Skills] Lesson cancelled. No payment was taken.");
}

public CmdCancelLesson(id)
{
    if (!id) return PLUGIN_HANDLED;
    new active = g_Lesson[id];
    CancelLesson(id, true);
    DestroyOwnMenu(id);
    if (!active) client_print(id, print_chat, "[Skills] No active lesson. Any open lesson menu has been closed.");
    return PLUGIN_HANDLED;
}

bool:LearningReady(id)
{
    new auth[36];
    if (!g_Ready || !PlayerIdentity(id, auth, charsmax(auth)))
    {
        client_print(id, print_chat, "[Skills] Wait for your Apollo account to load, or check the server log.");
        return false;
    }
    if (!get_pcvar_num(p_LearnEnabled))
    {
        client_print(id, print_chat, "[Skills] Learning is disabled on this server.");
        return false;
    }
    if (!is_user_alive(id))
    {
        client_print(id, print_chat, "[Skills] You must be alive to study.");
        return false;
    }
    if (g_Lesson[id])
    {
        client_print(id, print_chat, "[Skills] Studying %s: %d seconds remaining. Use /cancellearning to stop.",
            g_Labels[g_Lesson[id] - 1], max(0, floatround(g_LessonEnd[id] - get_gametime(), floatround_ceil)));
        return false;
    }
    return true;
}

bool:LessonSettings(skill, &price, &seconds, &gain)
{
    price = get_pcvar_num(p_LearnCost[skill]);
    seconds = get_pcvar_num(p_LearnSeconds);
    gain = get_pcvar_num(p_LearnGain);
    // Reject invalid server configuration instead of silently granting free lessons.
    return price >= 0 && price <= 1000000 && seconds >= 1 && seconds <= 3600 && gain >= 1 && gain <= SKILL_MAX;
}

public CmdPrices(id)
{
    new text[1024], pos, price, seconds, gain;
    pos = formatex(text, charsmax(text), "SELF-STUDY PRICES^nPayment: bank balance, on completion.^n^n");
    for (new i; i < SKILL_COUNT; i++)
    {
        if (LessonSettings(i, price, seconds, gain))
            pos += formatex(text[pos], charsmax(text) - pos, "%s: $%d, +%d point(s), %ds^n", g_Labels[i], price, gain, seconds);
        else pos += formatex(text[pos], charsmax(text) - pos, "%s: unavailable (invalid configuration)^n", g_Labels[i]);
    }
    formatex(text[pos], charsmax(text) - pos, "^n/skillmenu opens lessons. /cancellearning cancels.^nAt the skill cap, no lesson can be purchased.");
    show_motd(id, text, "Education Prices");
    return PLUGIN_HANDLED;
}

public CmdLearn(id)
{
    if (!LearningReady(id)) return PLUGIN_HANDLED;
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(id, values, auth, charsmax(auth)))
    {
        client_print(id, print_chat, "[Skills] Could not read skills; check the server log.");
        return PLUGIN_HANDLED;
    }
    DestroyOwnMenu(id);
    new title[128], label[128], info[8], price, seconds, gain;
    formatex(title, charsmax(title), "Self-study | Bank: $%d", ARP_GetUserBank(id));
    new menu = menu_create(title, "ChooseLesson");
    g_Menu[id] = menu;
    for (new i; i < SKILL_COUNT; i++)
    {
        num_to_str(i, info, charsmax(info));
        if (values[i] >= SKILL_MAX)
            formatex(label, charsmax(label), "%s: %d/%d (maximum)", g_Labels[i], values[i], SKILL_MAX);
        else if (LessonSettings(i, price, seconds, gain))
            formatex(label, charsmax(label), "%s %d/%d | +%d | $%d | %ds", g_Labels[i], values[i], SKILL_MAX, min(gain, SKILL_MAX - values[i]), price, seconds);
        else formatex(label, charsmax(label), "%s (unavailable)", g_Labels[i]);
        menu_additem(menu, label, info);
    }
    menu_setprop(menu, MPROP_EXITNAME, "Close");
    menu_display(id, menu, 0, 60);
    return PLUGIN_HANDLED;
}

public ChooseLesson(id, menu, item)
{
    if (g_Menu[id] != menu) return PLUGIN_HANDLED;
    g_Menu[id] = -1;
    if (item < 0)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    new access, callback, info[8], label[128];
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback);
    menu_destroy(menu);
    new skill = str_to_num(info);
    if (skill < 0 || skill >= SKILL_COUNT || !LearningReady(id)) return PLUGIN_HANDLED;
    new values[SKILL_COUNT], auth[36], price, seconds, gain;
    if (!LoadSkills(id, values, auth, charsmax(auth)) || !LessonSettings(skill, price, seconds, gain))
    {
        client_print(id, print_chat, "[Skills] Lesson unavailable: check the database/configuration.");
        return PLUGIN_HANDLED;
    }
    if (values[skill] >= SKILL_MAX || values[skill] < 0)
    {
        client_print(id, print_chat, "[Skills] No lesson available for this skill value.");
        return PLUGIN_HANDLED;
    }
    gain = min(gain, SKILL_MAX - values[skill]);
    if (ARP_GetUserBank(id) < price)
    {
        client_print(id, print_chat, "[Skills] You need $%d in your bank for this lesson.", price);
        return PLUGIN_HANDLED;
    }
    g_QuoteSkill[id] = skill;
    g_QuoteValue[id] = values[skill];
    g_QuotePrice[id] = price;
    g_QuoteGain[id] = gain;
    g_QuoteSeconds[id] = seconds;
    new title[256];
    formatex(title, charsmax(title), "Study %s?^n%d -> %d / %d^n%d seconds | $%d from BANK on completion^nCancel/death/disconnect: no charge", g_Labels[skill], values[skill], values[skill] + gain, SKILL_MAX, seconds, price);
    menu = menu_create(title, "ConfirmLesson");
    g_Menu[id] = menu;
    menu_additem(menu, "Start lesson", "start");
    menu_additem(menu, "Cancel", "cancel");
    menu_display(id, menu, 0, 30);
    return PLUGIN_HANDLED;
}

public ConfirmLesson(id, menu, item)
{
    if (g_Menu[id] != menu) return PLUGIN_HANDLED;
    g_Menu[id] = -1;
    menu_destroy(menu);
    if (item != 0 || !LearningReady(id)) return PLUGIN_HANDLED;
    new values[SKILL_COUNT], auth[36], skill = g_QuoteSkill[id];
    if (!LoadSkills(id, values, auth, charsmax(auth)))
    {
        client_print(id, print_chat, "[Skills] Could not load account. No lesson started.");
        return PLUGIN_HANDLED;
    }
    if (values[skill] != g_QuoteValue[id])
    {
        client_print(id, print_chat, "[Skills] Your skill value changed. Open /skillmenu again.");
        return PLUGIN_HANDLED;
    }
    if (ARP_GetUserBank(id) < g_QuotePrice[id])
    {
        client_print(id, print_chat, "[Skills] Insufficient bank funds. No lesson started.");
        return PLUGIN_HANDLED;
    }
    // Snapshot the confirmed terms; later cvar changes do not silently change price.
    g_Lesson[id] = skill + 1;
    g_LessonValue[id] = values[skill];
    g_LessonPrice[id] = g_QuotePrice[id];
    g_LessonGain[id] = g_QuoteGain[id];
    g_LessonUserid[id] = get_user_userid(id);
    copy(g_LessonAuth[id], charsmax(g_LessonAuth[]), auth);
    g_LessonEnd[id] = get_gametime() + float(g_QuoteSeconds[id]);
    client_print(id, print_chat, "[Skills] Studying %s for %d seconds. +%d point(s), $%d from BANK on completion.", g_Labels[skill], g_QuoteSeconds[id], g_QuoteGain[id], g_QuotePrice[id]);
    return PLUGIN_HANDLED;
}

public LessonTick()
{
    for (new id = 1; id <= 32; id++)
    {
        if (!g_Lesson[id]) continue;
        new auth[36];
        if (!g_Ready || !get_pcvar_num(p_LearnEnabled) || !is_user_alive(id) ||
            !PlayerIdentity(id, auth, charsmax(auth)) || get_user_userid(id) != g_LessonUserid[id] || !equal(auth, g_LessonAuth[id]))
        {
            CancelLesson(id, true);
            continue;
        }
        if (get_gametime() >= g_LessonEnd[id]) CompleteLesson(id);
    }
}

CompleteLesson(id)
{
    // Remove the active flag before any SQL work: this completion cannot run twice.
    new skill = g_Lesson[id] - 1, oldValue = g_LessonValue[id];
    new price = g_LessonPrice[id], gain = g_LessonGain[id];
    CancelLesson(id, false);
    new values[SKILL_COUNT], auth[36];
    if (!LoadSkills(id, values, auth, charsmax(auth)))
    {
        client_print(id, print_chat, "[Skills] Lesson failed to load your record. No charge or points.");
        return;
    }
    if (values[skill] != oldValue || oldValue < 0 || oldValue + gain > SKILL_MAX)
    {
        client_print(id, print_chat, "[Skills] Your skill value changed during the lesson. No charge or points.");
        return;
    }
    new bank = ARP_GetUserBank(id);
    if (bank < price)
    {
        client_print(id, print_chat, "[Skills] Not enough money left in your BANK. Lesson cancelled without points or payment.");
        return;
    }
    new sql[384];
    formatex(sql, charsmax(sql), "UPDATE arp_skills SET %s=%d WHERE steamid='%s' AND %s=%d", g_Keys[skill], oldValue + gain, auth, g_Keys[skill], oldValue);
    new Handle:q = RunQuery(sql);
    if (q == Empty_Handle)
    {
        client_print(id, print_chat, "[Skills] Lesson could not be saved. No payment taken; tell an admin.");
        return;
    }
    new changed = SQL_AffectedRows(q);
    SQL_FreeHandle(q);
    if (changed != 1)
    {
        client_print(id, print_chat, "[Skills] Record changed; no payment taken. Please try again.");
        return;
    }
    // Apollo manages bank persistence. Do not write Core's account table directly.
    ARP_SetUserBank(id, bank - price);
    log_amx("Lesson completed: %s %s %d -> %d, bank charged $%d", auth, g_Keys[skill], oldValue, oldValue + gain, price);
    client_print(id, print_chat, "[Skills] Lesson complete! %s: %d/%d. $%d paid from BANK. Progress saved.", g_Labels[skill], oldValue + gain, SKILL_MAX, price);
}
