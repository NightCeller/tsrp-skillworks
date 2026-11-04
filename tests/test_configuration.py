"""Check shipped operator configs against the actual registered Pawn defaults.

This protects upgrades from misspelled/obsolete cvars and accidental rebalance.
It does not execute Pawn or replace the in-game checklist.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTING = ROOT / 'addons/amxmodx/scripting'
CONFIGS = ROOT / 'addons/amxmodx/configs/arp'
MODULES = ('Skills', 'Cooking', 'Computers', 'Weapons', 'General', 'Drugs', 'Fighting', 'Law')


def array(source, name):
    match = re.search(r'new const ' + re.escape(name) + r'\[[^\]]+\]\[\]\s*=\s*\{([^}]+)\}', source)
    return re.findall(r'"([^"\n]*)"', match[1])


def defaults(module, source):
    found = dict(re.findall(r'register_cvar\("([^"]+)",\s*"(\d+)"\)', source))
    if module in ('Cooking', 'Weapons', 'General', 'Drugs'):
        for key, skill, seconds, cost in zip(array(source, 'g_Keys'), array(source, 'g_SkillDefaults'), array(source, 'g_TimeDefaults'), array(source, 'g_CostDefaults'), strict=True):
            prefix = f'arp_{module.lower()}'
            found.update({f'{prefix}_enabled_{key}': '1', f'{prefix}_skill_{key}': skill,
                          f'{prefix}_seconds_{key}': seconds, f'{prefix}_cost_{key}': cost})
    elif module == 'Skills':
        found.update({f'arp_skills_cost_{key}': cost for key, cost in zip(array(source, 'g_Keys'), array(source, 'g_DefaultCost'), strict=True)})
    elif module == 'Computers':
        found.update(dict(zip(array(source, 'g_Cvars'), array(source, 'g_Defaults'), strict=True)))
    return found


class ConfigurationContract(unittest.TestCase):
    def test_examples_match_every_registered_gameplay_default(self):
        for module in MODULES:
            with self.subTest(module=module):
                source = (SCRIPTING / f'ARP_{module}.sma').read_text()
                config = (CONFIGS / f'{module.lower()}.cfg').read_text()
                pairs = re.findall(r'^\s*(arp_\w+)\s+"?(\d+)"?\s*$', config, re.M)
                self.assertEqual(len(pairs), len(dict(pairs)), 'Duplicate cvar in example')
                self.assertEqual(dict(pairs), defaults(module, source))

    def test_recipe_defaults_preserve_existing_balance(self):
        baseline = {
            'Cooking': ([10, 10, 20], [30, 60, 60], [10, 35, 25]),
            'General': ([20, 20, 40, 60], [30, 30, 60, 90], [25, 1, 100, 250]),
            'Weapons': ([35, 35, 35, 50, 50, 50], [60, 60, 60, 120, 120, 90], [50, 50, 100, 150, 175, 100]),
            'Drugs': ([11, 16, 21, 31], [40, 60, 40, 90], [5, 10, 35, 75]),
        }
        for module, expected in baseline.items():
            source = (SCRIPTING / f'ARP_{module}.sma').read_text()
            actual = tuple([int(v) for v in array(source, name)] for name in ('g_SkillDefaults', 'g_TimeDefaults', 'g_CostDefaults'))
            self.assertEqual(actual, expected, module)

    def test_suite_versions_are_consistent(self):
        version = (ROOT / 'VERSION').read_text().strip()
        for module in MODULES:
            source = (SCRIPTING / f'ARP_{module}.sma').read_text()
            self.assertEqual(re.search(r'#define VERSION "([^"]+)"', source)[1], version)

    def test_experimental_combat_stays_opt_in_without_config(self):
        source = (SCRIPTING / 'ARP_Fighting.sma').read_text()
        self.assertEqual(defaults('Fighting', source)['arp_fighting_bonus_percent'], '0')


if __name__ == '__main__':
    unittest.main()
