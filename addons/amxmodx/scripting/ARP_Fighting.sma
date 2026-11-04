/*
 * TSRP SkillWorks — independent community project maintained by NightCeller.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE and NOTICE for terms and the Half-Life linking exception.
 */
/* SkillWorks Fighting 3.0.0-alpha.1 - configurable gameplay.
 * Skills are read-only. Apollo owns job persistence. No raw health writes.
 * Unarmed-only bonus: TSX converts WeaponInfo 0 to current weapon 36.
 * Jobs require explicit admin setup; never overwrite existing job definitions.
 */
#include <amxmodx>
#include <amxmisc>
#include <ApolloRP>
#include <ApolloRP_Chat>
#include <SkillWorks_Config>
#include <SkillWorks>
#include <hamsandwich>
#include <tsfun>

#define VERSION "3.0.0-alpha.1"
#define KUNGFU_WEAPON 36
#define SQL_SKILL "SELECT fighting FROM arp_skills WHERE steamid='%s'"
new const g_Jobs[][] = {"Dojo Worker", "Fighter"};
new const g_Salaries[] = {20, 30};
new Handle:g_Db = Empty_Handle;
new bool:g_Ready, bool:g_CoreError, bool:g_DamageHook;
new p_Required, p_Enabled, p_Jobs, p_Bonus, p_Debug;
new g_Menu[33] = {-1, ...}, g_Choice[33], g_QuotedSalary[33], g_QuotedRequired[33];
new g_CachedSkill[33], g_CachedUserid[33], g_CachedAuth[33][36];
new Float:g_CacheTime[33];

public ARP_Init()
{
    ARP_RegisterPlugin("Fighting", VERSION, "TSRP Server", "Fighting jobs and capped unarmed damage");
    ARP_RegisterChat("/fighting", "ChatFighting", "View Fighting bonus and choose a fighting job");
    ARP_RegisterTeamChat("/fighting", "ChatFighting", "View Fighting bonus and choose a fighting job");
    if (ARP_SqlMode() != SQLITE || !SQL_SetAffinity("sqlite"))
    { set_fail_state("Fighting requires Apollo SQLite mode."); return; }
    new error[256], code;
    g_Db = SQL_Connect(ARP_SqlHandle(), code, error, charsmax(error));
    if (g_Db == Empty_Handle)
    { log_amx("SQLite: %s", error); set_fail_state("Fighting could not connect to SQLite."); }
}
public plugin_init()
{
    register_cvar("arp_fighting_version", VERSION, FCVAR_SERVER);
    p_Enabled = register_cvar("arp_fighting_enabled", "1");
    p_Required = register_cvar("arp_fighting_job_skill", "16");
    p_Jobs = register_cvar("arp_fighting_jobs", "1");
    p_Bonus = register_cvar("arp_fighting_bonus_percent", "0");
    p_Debug = register_cvar("arp_fighting_debug", "0");
    register_clcmd("arp_fighting", "CmdMenu");
    register_concmd("arp_fighting_setup", "CmdSetup");
    if (IsHamValid(Ham_TakeDamage))
    { RegisterHam(Ham_TakeDamage, "player", "OnDamage", 0); g_DamageHook = true; }
    else log_amx("Ham_TakeDamage unavailable: damage bonus OFF; jobs remain available.");
    set_task(1.0, "RefreshSkills", 768001, "", 0, "b");
}
public plugin_cfg()
{
    new path[192];
    get_configsdir(path, charsmax(path));
    server_cmd("exec ^"%s/arp/fighting.cfg^"", path);
    new Handle:q = Query("SELECT fighting FROM arp_skills LIMIT 1");
    if (q == Empty_Handle)
    { set_fail_state("Load ARP_Skills before Fighting; arp_skills is required."); return; }
    SQL_FreeHandle(q);
    g_Ready = !g_CoreError;
    for (new r; r < sizeof g_Jobs; r++)
        SW_RegisterActivity(SW_FIGHTING, g_Jobs[r], p_Required, p_Jobs, p_Enabled, r, 0);
    log_amx("Fighting %s ready. Jobs require admin arp_fighting_setup. Damage hook=%d.", VERSION, g_DamageHook);
}
Handle:Query(const sql[])
{
    new Handle:q = SQL_PrepareQuery(g_Db, sql);
    if (q == Empty_Handle) return Empty_Handle;
    if (!SQL_Execute(q))
    {
        new error[256]; SQL_QueryError(q, error, charsmax(error));
        log_amx("Fighting query: %s", error); SQL_FreeHandle(q); return Empty_Handle;
    }
    return q;
}
bool:Identity(id, auth[], len)
{
    if (id < 1 || id > 32 || !is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || !ARP_PlayerReady(id)) return false;
    get_user_authid(id, auth, len);
    if (!equal(auth, "STEAM_", 6) || strlen(auth) < 11) return false;
    new colons;
    for (new i = 6; auth[i]; i++)
    {
        if (auth[i] == ':') colons++;
        else if (auth[i] < '0' || auth[i] > '9') return false;
    }
    return colons == 2;
}
Skill(id)
{
    new auth[36], sql[160];
    if (!g_Ready || !Identity(id, auth, charsmax(auth))) return -1;
    formatex(sql, charsmax(sql), SQL_SKILL, auth);
    new Handle:q = Query(sql);
    if (q == Empty_Handle) return -1;
    new value;
    if (SQL_NumResults(q)) value = SQL_ReadResult(q, 0);
    SQL_FreeHandle(q);
    return value >= 0 && value <= 100 ? value : -1;
}
public RefreshSkills()
{
    for (new id = 1; id <= 32; id++)
    {
        g_CachedSkill[id] = 0; g_CachedUserid[id] = 0;
        if (!g_Ready || !SW_Enabled(p_Enabled) || !is_user_alive(id)) continue;
        new auth[36];
        if (!Identity(id, auth, charsmax(auth))) continue;
        new skill = Skill(id);
        if (skill < 0) continue;
        g_CachedSkill[id] = skill;
        g_CachedUserid[id] = get_user_userid(id);
        copy(g_CachedAuth[id], charsmax(g_CachedAuth[]), auth);
        g_CacheTime[id] = get_gametime();
    }
}
Float:BonusLimit()
{
    // Invalid settings disable the bonus, rather than permitting excessive damage.
    new percent;
    return SW_ReadInt(p_Bonus, 0, 25, percent) ? float(percent) : 0.0;
}
public OnDamage(victim, inflictor, attacker, Float:damage, bits)
{
    if (!g_Ready || !SW_Enabled(p_Enabled) || attacker < 1 || attacker > 32 || victim < 1 || victim > 32 || attacker == victim) return HAM_IGNORED;
    if (!is_user_alive(attacker) || !is_user_alive(victim) || damage <= 0.0) return HAM_IGNORED;
    new weapon = ts_getuserwpn(attacker);
    // Conservative: unarmed, direct player damage only. Exclude bullet, explosion,
    // fall, burn and shock types even when another addon attributes these to a player.
    new bool:eligible = weapon == KUNGFU_WEAPON && inflictor == attacker && !(bits & ((1<<1)|(1<<3)|(1<<5)|(1<<6)|(1<<8)));
    if (SW_Enabled(p_Debug))
        log_amx("HIT attacker=%d victim=%d weapon=%d inflictor=%d bits=%d base=%.2f eligible=%d", attacker, victim, weapon, inflictor, bits, damage, eligible);
    if (!eligible || !g_CachedUserid[attacker] || get_user_userid(attacker) != g_CachedUserid[attacker] || get_gametime() - g_CacheTime[attacker] > 2.0) return HAM_IGNORED;
    new auth[36];
    if (!Identity(attacker, auth, charsmax(auth)) || !equal(auth, g_CachedAuth[attacker])) return HAM_IGNORED;
    new Float:bonus = BonusLimit() * float(g_CachedSkill[attacker]) / 100.0;
    if (bonus <= 0.0) return HAM_IGNORED;
    new Float:result = damage * (1.0 + bonus / 100.0);
    SetHamParamFloat(4, result);
    if (SW_Enabled(p_Debug)) log_amx("BONUS skill=%d percent=%.2f before=%.2f after=%.2f", g_CachedSkill[attacker], bonus, damage, result);
    return HAM_HANDLED;
}
ExactJob(const wanted[])
{
    new name[33];
    for (new job = 1; job <= ARP_GetJobsNum(); job++)
        if (ARP_ValidJobId(job) && ARP_GetJobName(job, name, charsmax(name)) && equal(name, wanted)) return job;
    return 0;
}
public CmdSetup(id)
{
    if (!g_Ready || (id && (!ARP_PlayerReady(id) || !ARP_AdminAccess(id))))
    { console_print(id, "[Fighting] Server console or loaded Apollo admin required."); return PLUGIN_HANDLED; }
    for (new r; r < sizeof g_Jobs; r++)
    {
        new job = ExactJob(g_Jobs[r]);
        if (job)
        { console_print(id, "[Fighting] %s exists; left unchanged (salary $%d, access %d).", g_Jobs[r], ARP_GetJobSalary(job), ARP_GetJobAccess(job)); continue; }
        new name[33], results[1]; copy(name, charsmax(name), g_Jobs[r]);
        if (ARP_FindJobId(name, results, 1))
        { console_print(id, "[Fighting] Similar job already exists for %s; resolve its name manually. Nothing overwritten.", name); continue; }
        ARP_AddJob(name, g_Salaries[r], 0);
        job = ExactJob(name);
        console_print(id, "[Fighting] %s: job ID %d, salary $%d, no access flags. Verify after restart.", name, job, g_Salaries[r]);
        log_amx("SETUP caller=%d job=%s id=%d", id, name, job);
    }
    return PLUGIN_HANDLED;
}
bool:Available(id)
{
    new auth[36];
    return g_Ready && SW_Enabled(p_Enabled) && is_user_alive(id) && Identity(id, auth, charsmax(auth));
}
CloseMenu(id)
{
    if (g_Menu[id] == -1) return;
    new menu = g_Menu[id]; g_Menu[id] = -1; menu_destroy(menu);
}
Selection(id, menu, item)
{
    if (g_Menu[id] != menu) return -1;
    g_Menu[id] = -1;
    new choice = -1, key[8], name[2], access, callback;
    if (item >= 0)
    {
        menu_item_getinfo(menu, item, access, key, charsmax(key), name, charsmax(name), callback);
        choice = str_to_num(key);
    }
    menu_destroy(menu); return choice;
}
bool:Eligible(id, r, &job, &required)
{
    if (!Available(id) || !SW_Enabled(p_Jobs)) return false;
    if (!SW_ReadInt(p_Required, 0, 100, required))
    { client_print(id, print_chat, "[Fighting] Invalid job skill setting; nothing changed."); return false; }
    if (Skill(id) < required)
    { client_print(id, print_chat, "[Fighting] Fighting %d required; skill must be available.", required); return false; }
    job = ExactJob(g_Jobs[r]);
    if (!job || ARP_GetJobAccess(job) != 0)
    { client_print(id, print_chat, "[Fighting] Job missing or has access flags. Ask an admin; self-enrolment blocked."); return false; }
    return true;
}
public ChatFighting(id, mode, const message[]) { return CmdMenu(id); }
public CmdMenu(id)
{
    if (!Available(id))
    { client_print(id, print_chat, "[Fighting] Be alive with your account loaded; Fighting must be enabled."); return PLUGIN_HANDLED; }
    new skill = Skill(id);
    if (skill < 0) { client_print(id, print_chat, "[Fighting] Skill unavailable; nothing changed."); return PLUGIN_HANDLED; }
    CloseMenu(id);
    new required;
    if (!SW_ReadInt(p_Required, 0, 100, required))
    { client_print(id, print_chat, "[Fighting] Invalid job skill setting; nothing changed."); return PLUGIN_HANDLED; }
    new title[192], line[128], key[8];
    new Float:bonus = g_DamageHook ? BonusLimit() * float(skill) / 100.0 : 0.0;
    formatex(title, charsmax(title), "Fighting %d/100 - unarmed bonus %.2f%%^nJobs require Fighting %d^nChoosing a job replaces your current job", skill, bonus, required);
    new menu = menu_create(title, "JobHandler");
    for (new r; r < sizeof g_Jobs; r++)
    {
        new job = ExactJob(g_Jobs[r]);
        if (!SW_Enabled(p_Jobs) || !job) formatex(line, charsmax(line), "%s - unavailable", g_Jobs[r]);
        else if (ARP_GetJobAccess(job)) formatex(line, charsmax(line), "%s - access flags: admin review required", g_Jobs[r]);
        else formatex(line, charsmax(line), "%s - $%d/hr", g_Jobs[r], ARP_GetJobSalary(job));
        num_to_str(r, key, charsmax(key)); menu_additem(menu, line, key);
    }
    g_Menu[id] = menu; menu_display(id, menu); return PLUGIN_HANDLED;
}
public JobHandler(id, menu, item)
{
    new r = Selection(id, menu, item), job, required;
    if (r < 0 || r >= sizeof g_Jobs || !Eligible(id, r, job, required)) return PLUGIN_HANDLED;
    g_Choice[id] = r; g_QuotedSalary[id] = ARP_GetJobSalary(job);
    g_QuotedRequired[id] = required;
    new title[192];
    formatex(title, charsmax(title), "Replace your current job with %s?^nSalary: $%d/hr^nNo fee. No special access flags.", g_Jobs[r], g_QuotedSalary[id]);
    new confirm = menu_create(title, "ConfirmJob");
    menu_additem(confirm, "Yes, change my job", "0");
    g_Menu[id] = confirm; menu_display(id, confirm); return PLUGIN_HANDLED;
}
public ConfirmJob(id, menu, item)
{
    if (Selection(id, menu, item) != 0) return PLUGIN_HANDLED;
    new r = g_Choice[id], job, required;
    if (!Eligible(id, r, job, required)) return PLUGIN_HANDLED;
    if (ARP_GetJobSalary(job) != g_QuotedSalary[id] || required != g_QuotedRequired[id])
    { client_print(id, print_chat, "[Fighting] Job terms changed; reopen /fighting."); return PLUGIN_HANDLED; }
    ARP_SetUserJobId(id, job);
    if (ARP_GetUserJobId(id) == job)
    {
        client_print(id, print_chat, "[Fighting] You are now a %s, $%d/hr. Fighting skill unchanged.", g_Jobs[r], g_QuotedSalary[id]);
        new auth[36]; get_user_authid(id, auth, charsmax(auth));
        log_amx("JOB steamid=%s job=%s id=%d", auth, g_Jobs[r], job);
    }
    return PLUGIN_HANDLED;
}
public client_disconnected(id) { g_CachedUserid[id] = 0; g_CachedSkill[id] = 0; CloseMenu(id); }
public client_putinserver(id) { g_CachedUserid[id] = 0; g_CachedSkill[id] = 0; CloseMenu(id); }
public ARP_Error(const reason[]) { g_CoreError = true; g_Ready = false; }
public plugin_end()
{
    for (new id = 1; id <= 32; id++) CloseMenu(id);
    if (g_Db != Empty_Handle) SQL_FreeHandle(g_Db);
}

public SW_ActivityAvailable(r)
{
    if (!g_Ready || r < 0 || r >= sizeof g_Jobs) return 0;
    new job = ExactJob(g_Jobs[r]);
    return job && ARP_GetJobAccess(job) == 0;
}
