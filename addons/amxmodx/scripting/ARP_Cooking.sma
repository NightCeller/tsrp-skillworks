/*
 * TSRP SkillWorks — independent community project maintained by NightCeller.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE and NOTICE for terms and the Half-Life linking exception.
 */
/* SkillWorks Cooking 3.0.0-alpha.1 - configurable gameplay.
 * Keep ARP_Skills installed. This addon reads its cooking column only.
 * Ingredient packs and supplies shop are new design, not an exact Harbu port.
 * Practical XP on completion; no random failures or location restriction.
 * Resources change only at completion. Apollo owns inventory/wallet persistence;
 * these in-memory operations are not a durable, crash-atomic SQL transaction.
 */
#include <amxmodx>
#include <amxmisc>
#include <ApolloRP>
#include <ApolloRP_Chat>
#include <SkillWorks_Config>
#include <SkillWorks>

#define VERSION "3.0.0-alpha.1"
new g_Activities[16];
#define RECIPES 3
#define MAX_STOCK 1000
new const g_Food[RECIPES][] = {"Fries", "Hamburger", "Pizza"};
new const g_Pack[RECIPES][] = {"Cooking Potato Pack", "Cooking Burger Pack", "Cooking Pizza Pack"};
new const g_Keys[RECIPES][] = {"fries", "hamburger", "pizza"};
new const g_SkillDefaults[RECIPES][] = {"10", "10", "20"};
new const g_TimeDefaults[RECIPES][] = {"30", "60", "60"};
new const g_CostDefaults[RECIPES][] = {"10", "35", "25"};
new p_Required[RECIPES], p_Time[RECIPES], p_Cost[RECIPES], p_RecipeEnabled[RECIPES];
new g_QuoteTime[33], g_QuoteRequired[33], g_QuoteSupply[33][RECIPES];
new g_RunTime[33], g_RunRequired[33];
new g_Input[RECIPES], g_Output[RECIPES];
new Handle:g_Db = Empty_Handle;
new bool:g_Ready, bool:g_CoreError;
new p_Enabled, p_Supplies;
new g_Menu[33] = {-1, ...};
new g_Active[33], g_Userid[33]; // recipe+1 or zero
new g_Auth[33][36];
new Float:g_End[33];

public plugin_init()
{
    register_cvar("arp_cooking_version", VERSION, FCVAR_SERVER);
    p_Enabled = register_cvar("arp_cooking_enabled", "1");
    p_Supplies = register_cvar("arp_cooking_supplies", "1");
    new name[64];
    for (new r; r < RECIPES; r++)
    {
        formatex(name, charsmax(name), "arp_cooking_skill_%s", g_Keys[r]);
        p_Required[r] = register_cvar(name, g_SkillDefaults[r]);
        formatex(name, charsmax(name), "arp_cooking_seconds_%s", g_Keys[r]);
        p_Time[r] = register_cvar(name, g_TimeDefaults[r]);
        formatex(name, charsmax(name), "arp_cooking_cost_%s", g_Keys[r]);
        p_Cost[r] = register_cvar(name, g_CostDefaults[r]);
        formatex(name, charsmax(name), "arp_cooking_enabled_%s", g_Keys[r]);
        p_RecipeEnabled[r] = register_cvar(name, "1");
    }
    register_clcmd("arp_cook", "CmdCook");
    register_clcmd("arp_cook_cancel", "CmdCancel");
    register_event("DeathMsg", "OnDeath", "a");
    set_task(1.0, "CookingTick", 763001, "", 0, "b");
}

public ARP_Init()
{
    ARP_RegisterPlugin("Cooking", VERSION, "TSRP Server", "Skill-gated cooking with inventory ingredients");
    ARP_RegisterChat("/cook", "ChatCook", "Cook food or buy ingredients");
    ARP_RegisterTeamChat("/cook", "ChatCook", "Cook food or buy ingredients");
    ARP_RegisterChat("/cancelcook", "ChatCancel", "Cancel cooking without using ingredients");
    ARP_RegisterTeamChat("/cancelcook", "ChatCancel", "Cancel cooking without using ingredients");
    if (ARP_SqlMode() != SQLITE || !SQL_SetAffinity("sqlite"))
    {
        set_fail_state("Cooking requires Apollo SQLite mode.");
        return;
    }
    new error[256], code;
    g_Db = SQL_Connect(ARP_SqlHandle(), code, error, charsmax(error));
    if (g_Db == Empty_Handle)
    {
        log_amx("Cooking SQLite connection: %s", error);
        set_fail_state("Cooking could not connect to SQLite.");
    }
}

public ARP_RegisterItems()
{
    for (new r; r < RECIPES; r++)
        g_Input[r] = ARP_RegisterItem(g_Pack[r], "UseIngredient", "One recipe portion. Use /cook to prepare food.", 0);
}

public plugin_cfg()
{
    new path[192];
    get_configsdir(path, charsmax(path));
    server_cmd("exec ^"%s/arp/cooking.cfg^"", path);
    // Resolve after all addons have registered their items.
    for (new r; r < RECIPES; r++)
    {
        g_Output[r] = ExactItem(g_Food[r]);
        if (!g_Input[r] || !g_Output[r])
        {
            log_amx("Missing ingredient or food: %s. Enable ARP_HungerMod.", g_Food[r]);
            set_fail_state("Cooking required items are unavailable.");
            return;
        }
    }
    new Handle:q = SQL_PrepareQuery(g_Db, "SELECT cooking FROM arp_skills LIMIT 1");
    if (!SQL_Execute(q))
    {
        SQL_FreeHandle(q);
        set_fail_state("Load ARP_Skills before ARP_Cooking; arp_skills table is required.");
        return;
    }
    SQL_FreeHandle(q);
    g_Ready = !g_CoreError;
    for (new r; r < RECIPES; r++)
        g_Activities[r] = SW_RegisterActivity(SW_COOKING, g_Food[r], p_Required[r], p_RecipeEnabled[r], p_Enabled, r, 1, 0, p_Time[r]);
    log_amx("ARP Cooking %s ready: three recipes, /cook, SQLite practical XP enabled.", VERSION);
}

ExactItem(const wanted[])
{
    new results[64], name[33], search[33];
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
    if (!g_Ready || !SW_Enabled(p_Enabled) || !is_user_alive(id) || !Identity(id, auth, charsmax(auth)))
    {
        if (is_user_connected(id)) client_print(id, print_chat, "[Cooking] Be alive with your account loaded; cooking must be enabled.");
        return false;
    }
    return true;
}

CookingSkill(id)
{
    new auth[36];
    if (!Identity(id, auth, charsmax(auth))) return -1;
    new Handle:q = SQL_PrepareQuery(g_Db, "SELECT cooking FROM arp_skills WHERE steamid='%s'", auth);
    if (!SQL_Execute(q))
    {
        new error[256];
        SQL_QueryError(q, error, charsmax(error));
        log_amx("Cooking skill read failed: %s", error);
        SQL_FreeHandle(q);
        return -1;
    }
    new value; // A new authenticated player has skill zero until Skills creates a row.
    if (SQL_NumResults(q)) value = SQL_ReadResult(q, 0);
    SQL_FreeHandle(q);
    return (value >= 0 && value <= 100) ? value : -1;
}

public ChatCook(id, mode, const message[]) { return CmdCook(id); }
public ChatCancel(id, mode, const message[]) { return CmdCancel(id); }
public UseIngredient(id, item)
{
    client_print(id, print_chat, "[Cooking] This is an ingredient pack. Open /cook to use it.");
    ARP_ItemDone(id);
}

CloseMenu(id)
{
    if (g_Menu[id] == -1) return;
    new menu = g_Menu[id];
    g_Menu[id] = -1;
    menu_destroy(menu);
}

public CmdCook(id)
{
    if (!Available(id)) return PLUGIN_HANDLED;
    if (g_Active[id])
    {
        client_print(id, print_chat, "[Cooking] Already cooking. Use /cancelcook to cancel.");
        return PLUGIN_HANDLED;
    }
    new skill = CookingSkill(id);
    if (skill < 0)
    {
        client_print(id, print_chat, "[Cooking] Could not read your skill; nothing changed.");
        return PLUGIN_HANDLED;
    }
    CloseMenu(id);
    new title[96], line[160], key[8], seconds, required;
    formatex(title, charsmax(title), "Cooking: %d/100^nOne pack makes one food item", skill);
    new menu = menu_create(title, "MainHandler");
    for (new r; r < RECIPES; r++)
    {
        if (RecipeSettings(r, seconds, required))
            formatex(line, charsmax(line), "%s - skill %d, %ds (packs: %d)", g_Food[r], required, seconds, ARP_GetUserItemNum(id, g_Input[r]));
        else formatex(line, charsmax(line), "%s - DISABLED / INVALID SETTINGS", g_Food[r]);
        num_to_str(r, key, charsmax(key));
        menu_additem(menu, line, key);
    }
    menu_additem(menu, "Buy ingredient packs (wallet)", "3");
    g_Menu[id] = menu;
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

// Destroy exactly our current menu; ignore callbacks from replaced menus.
TakeSelection(id, menu, item)
{
    if (g_Menu[id] != menu) return -1;
    g_Menu[id] = -1;
    new key[8], name[2], access, callback, choice = -1;
    if (item >= 0)
    {
        menu_item_getinfo(menu, item, access, key, charsmax(key), name, charsmax(name), callback);
        choice = str_to_num(key);
    }
    menu_destroy(menu);
    return choice;
}

public MainHandler(id, menu, item)
{
    new r = TakeSelection(id, menu, item);
    if (r < 0 || !Available(id) || g_Active[id]) return PLUGIN_HANDLED;
    if (r == RECIPES) { Supplies(id); return PLUGIN_HANDLED; }
    if (r >= RECIPES) return PLUGIN_HANDLED;
    new seconds, required;
    if (!RecipeSettings(r, seconds, required))
    { client_print(id, print_chat, "[Cooking] Recipe disabled or settings invalid. Nothing consumed."); return PLUGIN_HANDLED; }
    if (!CanCook(id, r, required)) return PLUGIN_HANDLED;
    g_QuoteTime[id] = seconds;
    g_QuoteRequired[id] = required;
    new title[192], key[8];
    formatex(title, charsmax(title), "Cook 1 %s?^nUses 1 %s on completion^nTime: %d seconds. Practical XP may apply.", g_Food[r], g_Pack[r], seconds);
    new confirm = menu_create(title, "ConfirmHandler");
    num_to_str(r, key, charsmax(key));
    menu_additem(confirm, "Start cooking", key);
    g_Menu[id] = confirm;
    menu_display(id, confirm);
    return PLUGIN_HANDLED;
}

bool:RecipeSettings(r, &seconds, &required)
{
    return SW_Enabled(p_RecipeEnabled[r])
        && SW_ReadInt(p_Time[r], 1, 3600, seconds)
        && SW_ReadInt(p_Required[r], 0, 100, required);
}

bool:SupplyPrice(r, &price)
{
    new seconds, required;
    return RecipeSettings(r, seconds, required) && SW_ReadInt(p_Cost[r], 0, 1000000, price);
}

bool:CanCook(id, r, required)
{
    new skill = CookingSkill(id);
    if (skill < required)
    {
        client_print(id, print_chat, "[Cooking] Requires Cooking %d; your skill is %d (negative means unavailable).", required, skill);
        return false;
    }
    if (ARP_GetUserItemNum(id, g_Input[r]) < 1)
    {
        client_print(id, print_chat, "[Cooking] You need one %s.", g_Pack[r]);
        return false;
    }
    if (ARP_GetUserItemNum(id, g_Output[r]) >= MAX_STOCK)
    {
        client_print(id, print_chat, "[Cooking] You already have at least %d of that food.", MAX_STOCK);
        return false;
    }
    return true;
}

public ConfirmHandler(id, menu, item)
{
    new r = TakeSelection(id, menu, item);
    if (r < 0 || r >= RECIPES || !Available(id) || g_Active[id]) return PLUGIN_HANDLED;
    new seconds, required;
    if (!RecipeSettings(r, seconds, required) || seconds != g_QuoteTime[id] || required != g_QuoteRequired[id])
    { client_print(id, print_chat, "[Cooking] Recipe changed; reopen /cook to review."); return PLUGIN_HANDLED; }
    if (!CanCook(id, r, required)) return PLUGIN_HANDLED;
    g_RunTime[id] = seconds;
    g_RunRequired[id] = required;
    g_Active[id] = r + 1;
    g_Userid[id] = get_user_userid(id);
    get_user_authid(id, g_Auth[id], charsmax(g_Auth[]));
    g_End[id] = get_gametime() + float(seconds);
    client_print(id, print_chat, "[Cooking] Preparing %s for %d seconds. /cancelcook cancels without using a pack.", g_Food[r], seconds);
    return PLUGIN_HANDLED;
}

Supplies(id)
{
    if (!SW_Enabled(p_Supplies))
    {
        client_print(id, print_chat, "[Cooking] The supplies menu is disabled.");
        return;
    }
    new menu = menu_create("Buy ONE pack - charges your WALLET", "SupplyHandler"), line[96], key[8], price;
    for (new r; r < RECIPES; r++)
    {
        g_QuoteSupply[id][r] = -1;
        if (SupplyPrice(r, price))
        {
            g_QuoteSupply[id][r] = price;
            formatex(line, charsmax(line), "%s - $%d", g_Pack[r], price);
        }
        else formatex(line, charsmax(line), "%s - DISABLED / INVALID SETTINGS", g_Pack[r]);
        num_to_str(r, key, charsmax(key));
        menu_additem(menu, line, key);
    }
    g_Menu[id] = menu;
    menu_display(id, menu);
}

public SupplyHandler(id, menu, item)
{
    new r = TakeSelection(id, menu, item);
    if (r < 0 || r >= RECIPES || !Available(id) || !SW_Enabled(p_Supplies) || g_Active[id]) return PLUGIN_HANDLED;
    new price;
    if (!SupplyPrice(r, price) || price != g_QuoteSupply[id][r])
    { client_print(id, print_chat, "[Cooking] Pack price changed or recipe disabled. Reopen /cook; nothing charged."); return PLUGIN_HANDLED; }
    new wallet = ARP_GetUserWallet(id), count = ARP_GetUserItemNum(id, g_Input[r]);
    if (wallet < price || count >= MAX_STOCK)
    {
        client_print(id, print_chat, "[Cooking] Insufficient wallet money or pack limit reached; nothing bought.");
        return PLUGIN_HANDLED;
    }
    ARP_SetUserItemNum(id, g_Input[r], count + 1);
    if (ARP_GetUserItemNum(id, g_Input[r]) != count + 1) return PLUGIN_HANDLED;
    ARP_SetUserWallet(id, wallet - price);
    if (ARP_GetUserWallet(id) != wallet - price)
    {
        ARP_SetUserItemNum(id, g_Input[r], count);
        client_print(id, print_chat, "[Cooking] Payment failed; removed the purchased pack.");
        return PLUGIN_HANDLED;
    }
    client_print(id, print_chat, "[Cooking] Bought 1 %s for $%d from your wallet.", g_Pack[r], price);
    return PLUGIN_HANDLED;
}

public CookingTick()
{
    for (new id = 1; id <= 32; id++)
    {
        if (!g_Active[id]) continue;
        new auth[36];
        if (!g_Ready || !SW_Enabled(p_Enabled) || !is_user_alive(id) || !Identity(id, auth, charsmax(auth)) || get_user_userid(id) != g_Userid[id] || !equal(auth, g_Auth[id]))
        {
            Cancel(id, true);
            continue;
        }
        new r = g_Active[id] - 1, seconds, required;
        if (!RecipeSettings(r, seconds, required) || seconds != g_RunTime[id] || required != g_RunRequired[id])
        {
            client_print(id, print_chat, "[Cooking] Recipe settings changed or disabled. Nothing consumed.");
            Cancel(id, false); continue;
        }
        if (get_gametime() < g_End[id]) continue;
        g_Active[id] = 0; // Clear before committing: never complete the same job twice.
        if (!CanCook(id, r, required))
        {
            client_print(id, print_chat, "[Cooking] Cancelled; requirements changed. Nothing consumed.");
            continue;
        }
        new packs = ARP_GetUserItemNum(id, g_Input[r]), food = ARP_GetUserItemNum(id, g_Output[r]);
        ARP_SetUserItemNum(id, g_Input[r], packs - 1);
        if (ARP_GetUserItemNum(id, g_Input[r]) != packs - 1) continue;
        ARP_SetUserItemNum(id, g_Output[r], food + 1);
        if (ARP_GetUserItemNum(id, g_Output[r]) != food + 1)
        {
            ARP_SetUserItemNum(id, g_Input[r], packs);
            client_print(id, print_chat, "[Cooking] Could not add food; restored the ingredient pack.");
            continue;
        }
        client_print(id, print_chat, "[Cooking] Finished! 1 %s added to /items; 1 pack used.", g_Food[r]);
        SW_AwardXP(id, g_Activities[r]);
        log_amx("Steam %s cooked 1 %s using 1 %s", auth, g_Food[r], g_Pack[r]);
    }
}

Cancel(id, bool:notify)
{
    new active = g_Active[id];
    g_Active[id] = 0;
    if (active && notify && is_user_connected(id))
        client_print(id, print_chat, "[Cooking] Cancelled. No ingredient pack used.");
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
    return g_Ready && r >= 0 && r < RECIPES && ARP_ValidItemId(g_Input[r]) && ARP_ValidItemId(g_Output[r]);
}
