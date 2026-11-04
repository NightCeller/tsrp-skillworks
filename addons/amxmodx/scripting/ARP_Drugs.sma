/*
 * TSRP SkillWorks — independent community project maintained by NightCeller.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE and NOTICE for terms and the Half-Life linking exception.
 */
/* SkillWorks Drugs 3.0.0-alpha.1 - configurable gameplay.
 * Requires ARP_Skills and ARP_Items. Reads levels; requests practical XP from ARP_Skills on success.
 * Adds existing Apollo consumable inventory items, uses their existing item handlers.
 * Wallet is charged only at completion after all requirements are rechecked.
 * Core owns persistence; wallet and inventory are not crash-atomic writes.
 */
#include <amxmodx>
#include <amxmisc>
#include <ApolloRP>
#include <ApolloRP_Chat>
#include <SkillWorks_Config>
#include <SkillWorks>

#define VERSION "3.0.0-alpha.1"
new g_Activities[16];
#define RECIPES 4
#define STOCK_LIMIT 1000
#define SQL_SKILL "SELECT drugs FROM arp_skills WHERE steamid='%s'"
new const g_Names[RECIPES][] = {"Cigarette", "Cuban Cigar", "Acid", "Cocaine"};
new const g_Keys[RECIPES][] = {"cigarette", "cigar", "acid", "cocaine"};
new const g_SkillDefaults[RECIPES][] = {"11", "16", "21", "31"};
new const g_CostDefaults[RECIPES][] = {"5", "10", "35", "75"};
new const g_TimeDefaults[RECIPES][] = {"40", "60", "40", "90"};
new g_Items[RECIPES], p_Cost[RECIPES], p_Time[RECIPES], p_Required[RECIPES], p_RecipeEnabled[RECIPES], p_Enabled;
new Handle:g_Db = Empty_Handle;
new bool:g_Ready, bool:g_CoreError;
new g_Menu[33] = {-1, ...};
new g_QuoteRecipe[33], g_QuoteCost[33], g_QuoteTime[33], g_QuoteRequired[33];
new g_Active[33], g_RunCost[33], g_RunTime[33], g_RunRequired[33], g_Userid[33], g_Auth[33][36];
new Float:g_End[33];

public plugin_init()
{
    register_cvar("arp_drugs_version", VERSION, FCVAR_SERVER);
    p_Enabled = register_cvar("arp_drugs_enabled", "1");
    new name[64];
    for (new r; r < RECIPES; r++)
    {
        formatex(name, charsmax(name), "arp_drugs_cost_%s", g_Keys[r]);
        p_Cost[r] = register_cvar(name, g_CostDefaults[r]);
        formatex(name, charsmax(name), "arp_drugs_seconds_%s", g_Keys[r]);
        p_Time[r] = register_cvar(name, g_TimeDefaults[r]);
        formatex(name, charsmax(name), "arp_drugs_skill_%s", g_Keys[r]);
        p_Required[r] = register_cvar(name, g_SkillDefaults[r]);
        formatex(name, charsmax(name), "arp_drugs_enabled_%s", g_Keys[r]);
        p_RecipeEnabled[r] = register_cvar(name, "1");
    }
    register_clcmd("arp_drugs", "CmdMenu");
    register_clcmd("arp_drugs_cancel", "CmdCancel");
    register_event("DeathMsg", "OnDeath", "a");
    set_task(1.0, "CraftTick", 767001, "", 0, "b");
}
public ARP_Init()
{
    ARP_RegisterPlugin("Drugs Crafting", VERSION, "TSRP Server", "Skill-gated consumable inventory crafting");
    ARP_RegisterChat("/drugs", "ChatDrugs", "Craft consumable inventory items with wallet money");
    ARP_RegisterTeamChat("/drugs", "ChatDrugs", "Craft consumable inventory items with wallet money");
    ARP_RegisterChat("/canceldrugs", "ChatCancel", "Cancel consumable crafting without payment");
    ARP_RegisterTeamChat("/canceldrugs", "ChatCancel", "Cancel consumable crafting without payment");
    if (ARP_SqlMode() != SQLITE || !SQL_SetAffinity("sqlite"))
    { set_fail_state("Drugs Crafting requires Apollo SQLite mode."); return; }
    new error[256], code;
    g_Db = SQL_Connect(ARP_SqlHandle(), code, error, charsmax(error));
    if (g_Db == Empty_Handle)
    {
        log_amx("Drugs SQLite connection: %s", error);
        set_fail_state("Drugs Crafting could not connect to SQLite.");
    }
}
public plugin_cfg()
{
    new path[192];
    get_configsdir(path, charsmax(path));
    server_cmd("exec ^"%s/arp/drugs.cfg^"", path);
    new available;
    for (new r; r < RECIPES; r++)
    {
        g_Items[r] = ExactItem(g_Names[r]);
        if (!g_Items[r])
        {
            log_amx("Recipe unavailable: %s was not resolved in the item registry.", g_Names[r]);
        }
        else available++;
    }
    if (!available) { set_fail_state("No Drugs crafting outputs available."); return; }
    new Handle:q = Query("SELECT drugs FROM arp_skills LIMIT 1");
    if (q == Empty_Handle)
    { set_fail_state("Load Skills before Drugs Crafting; arp_skills is required."); return; }
    SQL_FreeHandle(q);
    g_Ready = !g_CoreError;
    for (new r; r < RECIPES; r++)
        g_Activities[r] = SW_RegisterActivity(SW_DRUGS, g_Names[r], p_Required[r], p_RecipeEnabled[r], p_Enabled, r, 1, p_Cost[r], p_Time[r]);
    log_amx("ARP Drugs %s ready: %d/4 recipes available, /drugs; practical XP enabled.", VERSION, available);
}
Handle:Query(const sql[])
{
    new Handle:q = SQL_PrepareQuery(g_Db, sql);
    if (q == Empty_Handle) return Empty_Handle;
    if (!SQL_Execute(q))
    {
        new error[256];
        SQL_QueryError(q, error, charsmax(error));
        log_amx("Drugs skill query: %s", error);
        SQL_FreeHandle(q);
        return Empty_Handle;
    }
    return q;
}
ExactItem(const wanted[])
{
    new search[33], results[64], name[33];
    copy(search, charsmax(search), wanted);
    new count = ARP_FindItemId(search, results, sizeof results);
    for (new i; i < count && i < sizeof results; i++)
    {
        ARP_GetItemName(results[i], name, charsmax(name));
        if (equal(name, wanted)) return results[i];
    }
    return 0;
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
bool:Settings(r, &cost, &seconds, &required)
{
    return SW_Enabled(p_RecipeEnabled[r])
        && SW_ReadInt(p_Cost[r], 0, 1000000, cost)
        && SW_ReadInt(p_Time[r], 1, 3600, seconds)
        && SW_ReadInt(p_Required[r], 0, 100, required);
}
bool:Eligible(id, r, cost, required)
{
    if (!g_Items[r])
    {
        client_print(id, print_chat, "[Drugs] %s is unavailable on this server. Nothing charged.", g_Names[r]);
        return false;
    }
    new skill = Skill(id);
    if (skill < required)
    {
        client_print(id, print_chat, "[Drugs] Requires Drugs %d; yours is %d (negative means unavailable).", required, skill);
        return false;
    }
    if (ARP_GetUserWallet(id) < cost)
    {
        client_print(id, print_chat, "[Drugs] You need $%d in your wallet. Bank money is not used.", cost);
        return false;
    }
    if (!ARP_ValidItemId(g_Items[r]) || ARP_GetUserItemNum(id, g_Items[r]) >= STOCK_LIMIT)
    {
        client_print(id, print_chat, "[Drugs] Item unavailable or inventory count limit reached.");
        return false;
    }
    return true;
}
public ChatDrugs(id, mode, const message[]) { return CmdMenu(id); }
public ChatCancel(id, mode, const message[]) { return CmdCancel(id); }
CloseMenu(id)
{
    if (g_Menu[id] == -1) return;
    new menu = g_Menu[id];
    g_Menu[id] = -1;
    menu_destroy(menu);
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
    menu_destroy(menu);
    return choice;
}
public CmdMenu(id)
{
    if (!Available(id))
    { client_print(id, print_chat, "[Drugs] Be alive with your account loaded; crafting must be enabled."); return PLUGIN_HANDLED; }
    if (g_Active[id])
    { client_print(id, print_chat, "[Drugs] Already crafting. /canceldrugs cancels without payment."); return PLUGIN_HANDLED; }
    new skill = Skill(id);
    if (skill < 0)
    { client_print(id, print_chat, "[Drugs] Could not read your skill; nothing changed."); return PLUGIN_HANDLED; }
    CloseMenu(id);
    new title[96], line[160], key[8], cost, seconds, required;
    formatex(title, charsmax(title), "Drugs Crafting - skill %d/100^nWallet payment on completion", skill);
    new menu = menu_create(title, "RecipeHandler");
    for (new r; r < RECIPES; r++)
    {
        if (!SW_Enabled(p_RecipeEnabled[r]))
            formatex(line, charsmax(line), "%s - DISABLED / INVALID SWITCH", g_Names[r]);
        else if (!g_Items[r])
            formatex(line, charsmax(line), "%s - UNAVAILABLE", g_Names[r]);
        else if (Settings(r, cost, seconds, required))
            formatex(line, charsmax(line), "%s - skill %d, $%d, %ds", g_Names[r], required, cost, seconds);
        else formatex(line, charsmax(line), "%s - DISABLED / INVALID SETTINGS", g_Names[r]);
        num_to_str(r, key, charsmax(key));
        menu_additem(menu, line, key);
    }
    g_Menu[id] = menu;
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}
public RecipeHandler(id, menu, item)
{
    new r = Selection(id, menu, item);
    if (r < 0 || r >= RECIPES || !Available(id) || g_Active[id]) return PLUGIN_HANDLED;
    new cost, seconds, required;
    if (!Settings(r, cost, seconds, required))
    { client_print(id, print_chat, "[Drugs] Recipe disabled or settings invalid. Nothing changed."); return PLUGIN_HANDLED; }
    if (!Eligible(id, r, cost, required)) return PLUGIN_HANDLED;
    g_QuoteRecipe[id] = r;
    g_QuoteCost[id] = cost;
    g_QuoteTime[id] = seconds;
    g_QuoteRequired[id] = required;
    new title[256];
    formatex(title, charsmax(title), "Craft 1 %s?^nTime: %ds^nWallet charge at completion: $%d^nDelivered to /items. Practical XP may apply.^nCancel/death/disconnect: no charge.", g_Names[r], seconds, cost);
    new confirm = menu_create(title, "ConfirmHandler");
    menu_additem(confirm, "Start crafting", "0");
    g_Menu[id] = confirm;
    menu_display(id, confirm);
    return PLUGIN_HANDLED;
}
public ConfirmHandler(id, menu, item)
{
    new selected = Selection(id, menu, item);
    if (selected != 0 || !Available(id) || g_Active[id]) return PLUGIN_HANDLED;
    new r = g_QuoteRecipe[id], cost, seconds, required;
    if (!Settings(r, cost, seconds, required) || cost != g_QuoteCost[id] || seconds != g_QuoteTime[id] || required != g_QuoteRequired[id])
    { client_print(id, print_chat, "[Drugs] Recipe changed; reopen /drugs to review."); return PLUGIN_HANDLED; }
    if (!Eligible(id, r, cost, required)) return PLUGIN_HANDLED;
    g_Active[id] = r + 1;
    g_RunCost[id] = cost;
    g_RunTime[id] = seconds;
    g_RunRequired[id] = required;
    g_Userid[id] = get_user_userid(id);
    get_user_authid(id, g_Auth[id], charsmax(g_Auth[]));
    g_End[id] = get_gametime() + float(seconds);
    client_print(id, print_chat, "[Drugs] Crafting %s for %ds. Keep $%d in your wallet until completion.", g_Names[r], seconds, cost);
    return PLUGIN_HANDLED;
}
public CraftTick()
{
    for (new id = 1; id <= 32; id++)
    {
        if (!g_Active[id]) continue;
        new auth[36];
        if (!Available(id) || !Identity(id, auth, charsmax(auth)) || get_user_userid(id) != g_Userid[id] || !equal(auth, g_Auth[id]))
        { Cancel(id, true); continue; }
        new r = g_Active[id] - 1, cost, seconds, required;
        if (!Settings(r, cost, seconds, required) || cost != g_RunCost[id] || seconds != g_RunTime[id] || required != g_RunRequired[id])
        {
            client_print(id, print_chat, "[Drugs] Recipe settings changed or disabled. No charge.");
            Cancel(id, false); continue;
        }
        if (get_gametime() < g_End[id]) continue;
        g_Active[id] = 0; // Clear first so one timer job cannot pay out twice.
        if (!Eligible(id, r, cost, required))
        { client_print(id, print_chat, "[Drugs] Requirements changed; crafting cancelled without payment."); continue; }
        new count = ARP_GetUserItemNum(id, g_Items[r]), wallet = ARP_GetUserWallet(id);
        ARP_SetUserItemNum(id, g_Items[r], count + 1);
        if (ARP_GetUserItemNum(id, g_Items[r]) != count + 1)
        { client_print(id, print_chat, "[Drugs] Could not add the item; no charge."); continue; }
        ARP_SetUserWallet(id, wallet - cost);
        if (ARP_GetUserWallet(id) != wallet - cost)
        {
            ARP_SetUserItemNum(id, g_Items[r], count);
            client_print(id, print_chat, "[Drugs] Payment failed; removed the crafted item.");
            continue;
        }
        client_print(id, print_chat, "[Drugs] Crafted 1 %s in /items. Wallet charged $%d. Check /skills for progress.", g_Names[r], cost);
        SW_AwardXP(id, g_Activities[r]);
        log_amx("CRAFT %s item=%s cost=%d", auth, g_Names[r], cost);
    }
}
Cancel(id, bool:notify)
{
    new active = g_Active[id];
    g_Active[id] = 0;
    if (active && notify && is_user_connected(id)) client_print(id, print_chat, "[Drugs] Crafting cancelled. No charge and no item added.");
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

public SW_ActivityAvailable(r)
{
    return g_Ready && r >= 0 && r < RECIPES && ARP_ValidItemId(g_Items[r]);
}
