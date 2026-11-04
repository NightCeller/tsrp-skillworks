/* TSRP SkillWorks — independent community project maintained by NightCeller.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE and NOTICE for the Half-Life linking exception.
 */
#if defined _skillworks_config_included
    #endinput
#endif
#define _skillworks_config_included

// Unsigned decimal integers only. Reject malformed/overflowing settings instead
// of letting get_pcvar_num turn a typo into a zero price or skill requirement.
// The output is assigned only on success. Bounds must be nonnegative.
stock bool:SW_ParseInt(const text[], minimum, maximum, &value)
{
    if (!text[0] || minimum < 0 || maximum < minimum) return false;
    new parsed;
    for (new i; text[i]; i++)
    {
        if (text[i] < '0' || text[i] > '9') return false;
        new digit = text[i] - '0';
        if (parsed > maximum / 10 || (parsed == maximum / 10 && digit > maximum % 10)) return false;
        parsed = parsed * 10 + digit;
    }
    if (parsed < minimum) return false;
    value = parsed;
    return true;
}

stock bool:SW_ReadInt(pointer, minimum, maximum, &value)
{
    if (!pointer) return false;
    new text[64];
    // Reject a full buffer: its suffix may have been truncated.
    if (get_pcvar_string(pointer, text, charsmax(text)) >= charsmax(text)) return false;
    trim(text);
    return SW_ParseInt(text, minimum, maximum, value);
}

stock bool:SW_Enabled(pointer)
{
    new enabled;
    return SW_ReadInt(pointer, 0, 1, enabled) && enabled == 1;
}
