/*
 * TSRP SkillWorks — independent community project maintained by NightCeller.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE and NOTICE for terms and the Half-Life linking exception.
 */
/* SkillWorks Computers 3.0.0-alpha.1 - configurable gameplay.
 * Requires ARP_Skills, ARP_NPCs and SQLite Apollo.
 * Never edits skill values, existing NPC menus or player bank accounts.
 * A successful attempt creates wallet money. Practical XP is requested only after a successful payout.
 * Both cooldown keys are committed together BEFORE starting an attempt.
 * Cancellation never clears cooldowns. An interrupted attempt never resumes.
 * Wallet persistence belongs to Core; reward and cooldown are not crash-atomic.
 */
#include <amxmodx>
#include <amxmisc>
#include <ApolloRP>
#include <ApolloRP_Chat>
#include <SkillWorks_Config>
#include <SkillWorks>
new g_Activity;

#define VERSION "3.0.0-alpha.1"
#define KEY_LEN 128
#define WALLET_LIMIT 2000000000
#define SQL_CREATE "CREATE TABLE IF NOT EXISTS arp_computer_cooldowns (key TEXT PRIMARY KEY NOT NULL, until_ts INTEGER NOT NULL)"
#define SQL_GET "SELECT until_ts FROM arp_computer_cooldowns WHERE key='%s'"
#define SQL_PUT "INSERT OR REPLACE INTO arp_computer_cooldowns (key,until_ts) VALUES ('%s',%d)"
#define SQL_SKILL "SELECT computers FROM arp_skills WHERE steamid='%s'"

enum Settings { Required, Seconds, Cooldown, RewardMin, RewardMax, ChanceMin, ChanceMax, MinCops, Radius, Alerts };
new const g_Cvars[Settings][] = {
    "arp_hack_skill", "arp_hack_seconds", "arp_hack_cooldown", "arp_hack_reward_min", "arp_hack_reward_max",
    "arp_hack_chance_min", "arp_hack_chance_max", "arp_hack_min_cops", "arp_hack_radius", "arp_hack_alerts"
};
new const g_Defaults[Settings][] = {"31", "60", "300", "50", "150", "50", "90", "0", "100", "1"};
new p_Settings[Settings], p_Enabled;
new Handle:g_Db = Empty_Handle;
new bool:g_Ready, bool:g_CoreError;
new g_NpcPlugin = -1;
new g_Map[64];
new g_Menu[33] = {-1, ...};
new g_Quote[33][Settings], g_QuoteAtm[33], g_QuoteChance[33];
new g_QuoteKey[33][KEY_LEN];
new g_Active[33], g_Userid[33], g_Chance[33];
new g_Run[33][Settings], g_Auth[33][36], g_AtmKey[33][KEY_LEN];
new Float:g_End[33];

public plugin_init()
{
    register_cvar("arp_computers_version", VERSION, FCVAR_SERVER);
    p_Enabled = register_cvar("arp_hack_enabled", "1");
    for (new Settings:i; i < Settings; i++) p_Settings[i] = register_cvar(g_Cvars[i], g_Defaults[i]);
    register_clcmd("arp_computers", "CmdMenu");
    register_clcmd("arp_hack_cancel", "CmdCancel");
    register_event("DeathMsg", "OnDeath", "a");
    set_task(1.0, "HackTick", 764001, "", 0, "b");
}

public ARP_Init()
{
    ARP_RegisterPlugin("Computers", VERSION, "TSRP Server", "Skill-gated ATM attempts with persistent cooldowns");
    ARP_RegisterChat("/computers", "ChatComputers", "Use Computers skill near an ATM");
    ARP_RegisterTeamChat("/computers", "ChatComputers", "Use Computers skill near an ATM");
    // Apollo keys registrations by handler: aliases need separate wrappers.
    ARP_RegisterChat("/hackatm", "ChatHack", "Start an ATM attempt");
    ARP_RegisterTeamChat("/hackatm", "ChatHack", "Start an ATM attempt");
    ARP_RegisterChat("/cancelhack", "ChatCancel", "Cancel attempt; cooldown remains");
    ARP_RegisterTeamChat("/cancelhack", "ChatCancel", "Cancel attempt; cooldown remains");
    if (ARP_SqlMode() != SQLITE || !SQL_SetAffinity("sqlite"))
    {
        set_fail_state("Computers requires Apollo SQLite mode.");
        return;
    }
    new error[256], code;
    g_Db = SQL_Connect(ARP_SqlHandle(), code, error, charsmax(error));
    if (g_Db == Empty_Handle)
    {
        log_amx("SQLite connection failed: %s", error);
        set_fail_state("Computers SQLite connection failed.");
        return;
    }
    if (!ExecSQL(SQL_CREATE)) set_fail_state("Could not initialize Computers cooldown table.");
}

public plugin_cfg()
{
    new path[192];
    get_configsdir(path, charsmax(path));
    server_cmd("exec ^"%s/arp/computers.cfg^"", path);
    g_NpcPlugin = find_plugin_byfile("ARP_NPCs.amxx");
    if (g_NpcPlugin < 0) { set_fail_state("ARP_NPCs.amxx must be loaded before Computers."); return; }
    get_mapname(g_Map, charsmax(g_Map));
    // Map names become SQL key components; allow only the normal safe alphabet.
    for (new i; g_Map[i]; i++)
        if (!isalnum(g_Map[i]) && g_Map[i] != '_' && g_Map[i] != '-')
        { set_fail_state("Unsupported map name for ATM cooldown keys."); return; }
    new Handle:q = Query("SELECT computers FROM arp_skills LIMIT 1");
    if (q == Empty_Handle) { set_fail_state("Load ARP_Skills before Computers; arp_skills is required."); return; }
    SQL_FreeHandle(q);
    q = Query("SELECT key,until_ts FROM arp_computer_cooldowns LIMIT 1");
    if (q == Empty_Handle) { set_fail_state("Incompatible Computers cooldown table."); return; }
    SQL_FreeHandle(q);
    g_Ready = !g_CoreError;
    g_Activity = SW_RegisterActivity(SW_COMPUTERS, "ATM hacking", p_Settings[Required], p_Enabled, p_Enabled, 0);
    log_amx("ARP Computers %s ready: /computers near an Apollo ATM; persistent cooldowns.", VERSION);
}

Handle:Query(const sql[])
{
    new Handle:q = SQL_PrepareQuery(g_Db, sql);
    if (q == Empty_Handle) return Empty_Handle;
    if (!SQL_Execute(q))
    {
        new error[256];
        SQL_QueryError(q, error, charsmax(error));
        log_amx("Computers SQL error: %s", error);
        SQL_FreeHandle(q);
        return Empty_Handle;
    }
    return q;
}
bool:ExecSQL(const sql[])
{
    new Handle:q = Query(sql);
    if (q == Empty_Handle) return false;
    SQL_FreeHandle(q);
    return true;
}

bool:Identity(id, auth[], len)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || !ARP_PlayerReady(id)) return false;
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
bool:Available(id)
{
    new auth[36];
    return g_Ready && SW_Enabled(p_Enabled) && is_user_alive(id) && Identity(id, auth, charsmax(auth));
}
Skill(id)
{
    new auth[36], sql[256];
    if (!Identity(id, auth, charsmax(auth))) return -1;
    formatex(sql, charsmax(sql), SQL_SKILL, auth);
    new Handle:q = Query(sql);
    if (q == Empty_Handle) return -1;
    new value;
    if (SQL_NumResults(q)) value = SQL_ReadResult(q, 0);
    SQL_FreeHandle(q);
    return (value >= 0 && value <= 100) ? value : -1;
}
bool:LoadSettings(options[Settings])
{
    for (new Settings:i; i < Settings; i++)
        if (!SW_ReadInt(p_Settings[i], 0, 604800, options[i])) return false;
    return options[Required] >= 0 && options[Required] <= 100
        && options[Seconds] >= 1 && options[Seconds] <= 3600
        && options[Cooldown] >= 1 && options[Cooldown] <= 604800
        && options[RewardMin] >= 0 && options[RewardMax] >= options[RewardMin] && options[RewardMax] <= 100000
        && options[ChanceMin] >= 0 && options[ChanceMax] >= options[ChanceMin] && options[ChanceMax] <= 100
        && options[MinCops] >= 0 && options[MinCops] <= 32
        && options[Radius] >= 30 && options[Radius] <= 150
        && options[Alerts] >= 0 && options[Alerts] <= 1;
}
Chance(skill, const options[Settings])
{
    if (options[Required] == 100) return options[ChanceMax];
    return options[ChanceMin] + (skill - options[Required]) * (options[ChanceMax] - options[ChanceMin]) / (100 - options[Required]);
}
CopCount()
{
    new total;
    for (new id = 1; id <= 32; id++)
        if (is_user_connected(id) && ARP_PlayerReady(id) && ARP_IsCop(id)) total++;
    return total;
}

bool:IsAtm(ent)
{
    if (!is_valid_ent(ent) || !ARP_IsNpc(ent)) return false;
    if (entity_get_int(ent, EV_INT_iuser3) != g_NpcPlugin) return false;
    new handler[32];
    entity_get_string(ent, EV_SZ_noise, handler, charsmax(handler));
    return equal(handler, "AtmHandle") != 0;
}
AtmKey(ent, key[], len)
{
    new Float:origin[3];
    entity_get_vector(ent, EV_VEC_origin, origin);
    // Coordinates rather than transient entity index preserve keys across reloads.
    formatex(key, len, "A:%s:%d:%d:%d", g_Map, floatround(origin[0]), floatround(origin[1]), floatround(origin[2]));
}
bool:NearAtm(id, ent, radius)
{
    if (!IsAtm(ent)) return false;
    new Float:player[3], Float:atm[3];
    entity_get_vector(id, EV_VEC_origin, player);
    entity_get_vector(ent, EV_VEC_origin, atm);
    return get_distance_f(player, atm) <= float(radius);
}
NearestAtm(id, radius)
{
    new ent, best, Float:closest = float(radius) + 0.01;
    new Float:player[3], Float:atm[3], Float:distance;
    entity_get_vector(id, EV_VEC_origin, player);
    while ((ent = find_ent_in_sphere(ent, player, float(radius))))
    {
        if (!IsAtm(ent)) continue;
        entity_get_vector(ent, EV_VEC_origin, atm);
        distance = get_distance_f(player, atm);
        if (distance < closest) { closest = distance; best = ent; }
    }
    return best;
}

// Returns seconds remaining, zero if free, -1 on database error.
Remaining(const key[], now)
{
    new sql[256];
    formatex(sql, charsmax(sql), SQL_GET, key);
    new Handle:q = Query(sql);
    if (q == Empty_Handle) return -1;
    new until;
    if (SQL_NumResults(q)) until = SQL_ReadResult(q, 0);
    SQL_FreeHandle(q);
    return until > now ? until - now : 0;
}

// Atomic reservation of BOTH keys, using the same connection throughout.
// 1=claimed; 0=blocked; -1=SQL/time error. Never start if COMMIT fails.
Claim(const playerKey[], const atmKey[], seconds, cooldown, &remaining)
{
    new now = get_systime();
    if (now < 0 || now > 2146870000) return -1;
    if (!ExecSQL("BEGIN IMMEDIATE")) return -1;
    new p = Remaining(playerKey, now), a = Remaining(atmKey, now);
    if (p < 0 || a < 0) { ExecSQL("ROLLBACK"); return -1; }
    remaining = max(p, a);
    if (remaining) { ExecSQL("ROLLBACK"); return 0; }
    new until = now + seconds + cooldown, sql[256];
    formatex(sql, charsmax(sql), SQL_PUT, playerKey, until);
    if (!ExecSQL(sql)) { ExecSQL("ROLLBACK"); return -1; }
    formatex(sql, charsmax(sql), SQL_PUT, atmKey, until);
    if (!ExecSQL(sql)) { ExecSQL("ROLLBACK"); return -1; }
    if (!ExecSQL("COMMIT")) { ExecSQL("ROLLBACK"); return -1; }
    return 1;
}

public ChatComputers(id, mode, const message[]) { return CmdMenu(id); }
public ChatHack(id, mode, const message[]) { return CmdMenu(id); }
public ChatCancel(id, mode, const message[]) { return CmdCancel(id); }
CloseMenu(id)
{
    if (g_Menu[id] == -1) return;
    new menu = g_Menu[id];
    g_Menu[id] = -1;
    menu_destroy(menu);
}
public CmdMenu(id)
{
    if (!Available(id))
    {
        client_print(id, print_chat, "[Computers] Be alive with your account loaded; ATM hacking must be enabled.");
        return PLUGIN_HANDLED;
    }
    if (g_Active[id])
    {
        client_print(id, print_chat, "[Computers] Already attempting an ATM. /cancelhack cancels; cooldown remains.");
        return PLUGIN_HANDLED;
    }
    CloseMenu(id);
    if (!LoadSettings(g_Quote[id]))
    {
        client_print(id, print_chat, "[Computers] Invalid server configuration. Contact an administrator.");
        return PLUGIN_HANDLED;
    }
    new skill = Skill(id);
    if (skill < 0 || skill < g_Quote[id][Required])
    {
        client_print(id, print_chat, "[Computers] Requires Computers %d; yours is %d (negative means unavailable).", g_Quote[id][Required], skill);
        return PLUGIN_HANDLED;
    }
    new ent = NearestAtm(id, g_Quote[id][Radius]);
    if (!ent)
    {
        client_print(id, print_chat, "[Computers] Stand next to an Apollo ATM, then use /computers.");
        return PLUGIN_HANDLED;
    }
    new auth[36], key[KEY_LEN];
    Identity(id, auth, charsmax(auth));
    formatex(key, charsmax(key), "P:%s", auth);
    AtmKey(ent, g_QuoteKey[id], charsmax(g_QuoteKey[]));
    new p = Remaining(key, get_systime()), a = Remaining(g_QuoteKey[id], get_systime());
    if (p < 0 || a < 0 || p || a)
    {
        client_print(id, print_chat, "[Computers] Player cooldown: %ds; ATM cooldown: %ds. Negative means database unavailable.", p, a);
        return PLUGIN_HANDLED;
    }
    if (CopCount() < g_Quote[id][MinCops])
    {
        client_print(id, print_chat, "[Computers] Requires %d police online.", g_Quote[id][MinCops]);
        return PLUGIN_HANDLED;
    }
    g_QuoteAtm[id] = ent;
    g_QuoteChance[id] = Chance(skill, g_Quote[id]);
    new title[512];
    formatex(title, charsmax(title), "ATM attempt - Computers %d^nTime: %ds | Chance: %d%%^nWallet reward: $%d-$%d on success^nStay nearby. Police alert: %s^nCooldown: %ds after scheduled finish^nCancel/death/disconnect keeps cooldown.", skill, g_Quote[id][Seconds], g_QuoteChance[id], g_Quote[id][RewardMin], g_Quote[id][RewardMax], g_Quote[id][Alerts] ? "ON" : "OFF", g_Quote[id][Cooldown]);
    new menu = menu_create(title, "Confirm");
    menu_additem(menu, "Start ATM attempt", "1");
    g_Menu[id] = menu;
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Confirm(id, menu, item)
{
    if (menu != g_Menu[id]) return PLUGIN_HANDLED;
    g_Menu[id] = -1;
    menu_destroy(menu);
    if (item != 0 || !Available(id) || g_Active[id]) return PLUGIN_HANDLED;
    new current[Settings];
    if (!LoadSettings(current)) return PLUGIN_HANDLED;
    for (new Settings:i; i < Settings; i++)
        if (current[i] != g_Quote[id][i])
        { client_print(id, print_chat, "[Computers] Settings changed; reopen /computers to review."); return PLUGIN_HANDLED; }
    new ent = g_QuoteAtm[id], key[KEY_LEN], auth[36], playerKey[KEY_LEN];
    if (!NearAtm(id, ent, current[Radius]))
    { client_print(id, print_chat, "[Computers] You moved away from the ATM."); return PLUGIN_HANDLED; }
    AtmKey(ent, key, charsmax(key));
    if (!equal(key, g_QuoteKey[id])) return PLUGIN_HANDLED;
    new skill = Skill(id);
    if (skill < current[Required] || Chance(skill, current) != g_QuoteChance[id])
    { client_print(id, print_chat, "[Computers] Skill changed or unavailable; reopen /computers."); return PLUGIN_HANDLED; }
    if (CopCount() < current[MinCops])
    { client_print(id, print_chat, "[Computers] Not enough police online."); return PLUGIN_HANDLED; }
    if (ARP_GetUserWallet(id) < 0 || ARP_GetUserWallet(id) > WALLET_LIMIT - current[RewardMax])
    { client_print(id, print_chat, "[Computers] Wallet limit prevents receiving a reward."); return PLUGIN_HANDLED; }
    Identity(id, auth, charsmax(auth));
    formatex(playerKey, charsmax(playerKey), "P:%s", auth);
    new remaining, result = Claim(playerKey, key, current[Seconds], current[Cooldown], remaining);
    if (result != 1)
    {
        if (!result) client_print(id, print_chat, "[Computers] Player or ATM unavailable for %d seconds.", remaining);
        else client_print(id, print_chat, "[Computers] Could not save cooldowns. Attempt not started.");
        return PLUGIN_HANDLED;
    }
    g_Active[id] = ent;
    g_Userid[id] = get_user_userid(id);
    copy(g_Auth[id], charsmax(g_Auth[]), auth);
    copy(g_AtmKey[id], charsmax(g_AtmKey[]), key);
    for (new Settings:i; i < Settings; i++) g_Run[id][i] = current[i];
    g_Chance[id] = g_QuoteChance[id];
    g_End[id] = get_gametime() + float(current[Seconds]);
    client_print(id, print_chat, "[Computers] Attempt started: %ds. Stay near this ATM. /cancelhack keeps your cooldown.", current[Seconds]);
    log_amx("START %s at %s chance=%d seconds=%d", auth, key, g_Chance[id], current[Seconds]);
    if (current[Alerts]) AlertPolice(ent);
    return PLUGIN_HANDLED;
}
AlertPolice(ent)
{
    new Float:origin[3];
    entity_get_vector(ent, EV_VEC_origin, origin);
    for (new id = 1; id <= 32; id++)
        if (is_user_connected(id) && ARP_PlayerReady(id) && ARP_IsCop(id))
            client_print(id, print_chat, "[Police] ATM tampering reported at %d, %d, %d on %s.", floatround(origin[0]), floatround(origin[1]), floatround(origin[2]), g_Map);
}
public HackTick()
{
    for (new id = 1; id <= 32; id++)
    {
        if (!g_Active[id]) continue;
        new auth[36], key[KEY_LEN];
        if (!Available(id) || !Identity(id, auth, charsmax(auth)) || !equal(auth, g_Auth[id]) || get_user_userid(id) != g_Userid[id])
        { Cancel(id, true); continue; }
        new current[Settings], bool:changed = !LoadSettings(current);
        for (new Settings:i; i < Settings; i++)
            if (current[i] != g_Run[id][i]) changed = true;
        if (changed)
        {
            client_print(id, print_chat, "[Computers] ATM settings changed or invalid. Attempt cancelled; cooldown remains.");
            Cancel(id, false); continue;
        }
        if (!NearAtm(id, g_Active[id], g_Run[id][Radius]))
        { Cancel(id, true); continue; }
        AtmKey(g_Active[id], key, charsmax(key));
        if (!equal(key, g_AtmKey[id])) { Cancel(id, true); continue; }
        if (get_gametime() < g_End[id]) continue;
        g_Active[id] = 0; // Clear before one-shot outcome; timer cannot pay twice.
        if (Skill(id) < g_Run[id][Required] || CopCount() < g_Run[id][MinCops])
        {
            client_print(id, print_chat, "[Computers] Requirements no longer met. No reward; cooldown remains.");
            log_amx("CANCEL requirements %s at %s", auth, key);
            continue;
        }
        if (random_num(1, 100) > g_Chance[id])
        {
            client_print(id, print_chat, "[Computers] Attempt failed. No money gained or taken; cooldown remains.");
            log_amx("FAIL %s at %s", auth, key);
            continue;
        }
        new amount = random_num(g_Run[id][RewardMin], g_Run[id][RewardMax]);
        new wallet = ARP_GetUserWallet(id);
        if (wallet < 0 || wallet > WALLET_LIMIT - amount)
        { client_print(id, print_chat, "[Computers] Wallet limit: no reward added; cooldown remains."); continue; }
        ARP_SetUserWallet(id, wallet + amount);
        if (ARP_GetUserWallet(id) != wallet + amount)
        { client_print(id, print_chat, "[Computers] Reward failed; no XP awarded."); continue; }
        SW_AwardXP(id, g_Activity);
        client_print(id, print_chat, "[Computers] Success! $%d added to your wallet. Check /skills for progress.", amount);
        log_amx("SUCCESS %s at %s reward=%d", auth, key, amount);
    }
}
Cancel(id, bool:notify)
{
    if (!g_Active[id]) return;
    g_Active[id] = 0;
    log_amx("CANCEL %s at %s; cooldown retained", g_Auth[id], g_AtmKey[id]);
    if (notify && is_user_connected(id)) client_print(id, print_chat, "[Computers] Attempt cancelled. No reward; cooldown remains.");
}
public CmdCancel(id) { Cancel(id, true); CloseMenu(id); return PLUGIN_HANDLED; }
public OnDeath() { new id = read_data(2); Cancel(id, true); CloseMenu(id); }
public client_disconnected(id) { Cancel(id, false); CloseMenu(id); }
public client_putinserver(id) { Cancel(id, false); CloseMenu(id); }
public ARP_Error(const reason[]) { g_CoreError = true; g_Ready = false; }
public plugin_end()
{
    for (new id = 1; id <= 32; id++) { Cancel(id, false); CloseMenu(id); }
    if (g_Db != Empty_Handle) SQL_FreeHandle(g_Db);
}

public SW_ActivityAvailable(localIndex)
{
    new options[Settings];
    return g_Ready && LoadSettings(options);
}
