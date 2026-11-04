/*
 * TSRP SkillWorks — independent community project maintained by NightCeller.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE and NOTICE for terms and the Half-Life linking exception.
 */
/* SkillWorks Law 3.0.0-alpha.1 - configurable gameplay.
 * Configurable Law threshold (default 21) for Lawyer, Jury and City Judge.
 * Reads existing skills; Apollo owns salary and job persistence.
 * Existing job definitions are never overwritten. Admin setup creates missing jobs.
 * Only empty access or the stock Mecklenburg t flag is permitted for enrolment.
 */
#include <amxmodx>
#include <amxmisc>
#include <ApolloRP>
#include <ApolloRP_Chat>
#include <SkillWorks_Config>
#include <SkillWorks>

#define VERSION "3.0.0-alpha.1"
#define SQL_SKILL "SELECT law FROM arp_skills WHERE steamid='%s'"
new const g_Jobs[][] = {"Lawyer", "Jury", "City Judge"};
new const g_Salaries[] = {20, 20, 30};
new Handle:g_Db = Empty_Handle;
new bool:g_Ready, bool:g_CoreError;
new p_Required, p_Enabled;
new g_Menu[33] = {-1, ...}, g_Choice[33], g_QuotedSalary[33], g_QuotedRequired[33];

public ARP_Init()
{
    ARP_RegisterPlugin("Law", VERSION, "TSRP Server", "Skill-gated legal job selection");
    ARP_RegisterChat("/law", "ChatLaw", "Choose a skill-gated legal job");
    ARP_RegisterTeamChat("/law", "ChatLaw", "Choose a skill-gated legal job");
    if (ARP_SqlMode() != SQLITE || !SQL_SetAffinity("sqlite"))
    { set_fail_state("Law requires Apollo SQLite mode."); return; }
    new error[256], code;
    g_Db = SQL_Connect(ARP_SqlHandle(), code, error, charsmax(error));
    if (g_Db == Empty_Handle)
    { log_amx("SQLite: %s", error); set_fail_state("Law could not connect to SQLite."); }
}
public plugin_init()
{
    register_cvar("arp_law_version", VERSION, FCVAR_SERVER);
    p_Enabled = register_cvar("arp_law_enabled", "1");
    p_Required = register_cvar("arp_law_job_skill", "21");
    register_clcmd("arp_law", "CmdMenu");
    register_concmd("arp_law_setup", "CmdSetup");

}
public plugin_cfg()
{
    new path[192];
    get_configsdir(path, charsmax(path));
    server_cmd("exec ^"%s/arp/law.cfg^"", path);
    new Handle:q = Query("SELECT law FROM arp_skills LIMIT 1");
    if (q == Empty_Handle)
    { set_fail_state("Load ARP_Skills before Law; arp_skills is required."); return; }
    SQL_FreeHandle(q);
    g_Ready = !g_CoreError;
    for (new r; r < sizeof g_Jobs; r++)
        SW_RegisterActivity(SW_LAW, g_Jobs[r], p_Required, p_Enabled, p_Enabled, r, 0);
    log_amx("Law %s ready. Jobs can be prepared with admin arp_law_setup.", VERSION);
}
Handle:Query(const sql[])
{
    new Handle:q = SQL_PrepareQuery(g_Db, sql);
    if (q == Empty_Handle) return Empty_Handle;
    if (!SQL_Execute(q))
    {
        new error[256]; SQL_QueryError(q, error, charsmax(error));
        log_amx("Law query: %s", error); SQL_FreeHandle(q); return Empty_Handle;
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
ExactJob(const wanted[])
{
    new name[33];
    for (new job = 1; job <= ARP_GetJobsNum(); job++)
        if (ARP_ValidJobId(job) && ARP_GetJobName(job, name, charsmax(name)) && equal(name, wanted)) return job;
    return 0;
}
bool:SafeJobAccess(job)
{
    // Accept stock civilian t, but refuse extra flags (police, medical, admin, etc.).
    new access = ARP_GetJobAccess(job), allowed = ARP_AccessToInt("t");
    // Respect servers that repurpose t as the Apollo administrator flag.
    return !(access & ~allowed) && !(access & ARP_AdminAccess());
}
public CmdSetup(id)
{
    if (!g_Ready || (id && (!ARP_PlayerReady(id) || !ARP_AdminAccess(id))))
    { console_print(id, "[Law] Server console or loaded Apollo admin required."); return PLUGIN_HANDLED; }
    for (new r; r < sizeof g_Jobs; r++)
    {
        new job = ExactJob(g_Jobs[r]);
        if (job)
        { console_print(id, "[Law] %s exists; left unchanged (salary $%d, access %d).", g_Jobs[r], ARP_GetJobSalary(job), ARP_GetJobAccess(job)); continue; }
        new name[33], results[1]; copy(name, charsmax(name), g_Jobs[r]);
        if (ARP_FindJobId(name, results, 1))
        { console_print(id, "[Law] Similar job already exists for %s; resolve its name manually. Nothing overwritten.", name); continue; }
        ARP_AddJob(name, g_Salaries[r], ARP_AccessToInt("t"));
        job = ExactJob(name);
        console_print(id, "[Law] %s: job ID %d, salary $%d, access t. Verify after restart.", name, job, g_Salaries[r]);
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
    if (!Available(id)) return false;
    if (!SW_ReadInt(p_Required, 0, 100, required))
    { client_print(id, print_chat, "[Law] Invalid job skill setting; nothing changed."); return false; }
    if (Skill(id) < required)
    { client_print(id, print_chat, "[Law] Law %d required; skill must be available.", required); return false; }
    job = ExactJob(g_Jobs[r]);
    if (!job || !SafeJobAccess(job))
    { client_print(id, print_chat, "[Law] Job missing or has access beyond stock t. Ask an admin; self-enrolment blocked."); return false; }
    return true;
}
public ChatLaw(id, mode, const message[]) { return CmdMenu(id); }
public CmdMenu(id)
{
    if (!Available(id))
    { client_print(id, print_chat, "[Law] Be alive with your account loaded; Law must be enabled."); return PLUGIN_HANDLED; }
    new skill = Skill(id);
    if (skill < 0) { client_print(id, print_chat, "[Law] Skill unavailable; nothing changed."); return PLUGIN_HANDLED; }
    CloseMenu(id);
    new required;
    if (!SW_ReadInt(p_Required, 0, 100, required))
    { client_print(id, print_chat, "[Law] Invalid job skill setting; nothing changed."); return PLUGIN_HANDLED; }
    new title[192], line[128], key[8];
    formatex(title, charsmax(title), "Law %d/100^nJobs require Law %d^nChoosing a job replaces your current job", skill, required);
    new menu = menu_create(title, "JobHandler");
    for (new r; r < sizeof g_Jobs; r++)
    {
        new job = ExactJob(g_Jobs[r]);
        if (!job) formatex(line, charsmax(line), "%s - unavailable", g_Jobs[r]);
        else if (!SafeJobAccess(job)) formatex(line, charsmax(line), "%s - access flags: admin review required", g_Jobs[r]);
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
    formatex(title, charsmax(title), "Replace your current job with %s?^nSalary: $%d/hr^nNo fee. Uses the existing job access.", g_Jobs[r], g_QuotedSalary[id]);
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
    { client_print(id, print_chat, "[Law] Job terms changed; reopen /law."); return PLUGIN_HANDLED; }
    ARP_SetUserJobId(id, job);
    if (ARP_GetUserJobId(id) == job)
    {
        client_print(id, print_chat, "[Law] You are now a %s, $%d/hr. Law skill unchanged.", g_Jobs[r], g_QuotedSalary[id]);
        new auth[36]; get_user_authid(id, auth, charsmax(auth));
        log_amx("JOB steamid=%s job=%s id=%d", auth, g_Jobs[r], job);
    }
    return PLUGIN_HANDLED;
}
public client_disconnected(id) { CloseMenu(id); }
public client_putinserver(id) { CloseMenu(id); }
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
    return job && SafeJobAccess(job);
}
