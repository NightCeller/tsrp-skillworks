"""V3 SQL contracts and progression reference-model boundary tests.
SQL statements are extracted from shipped Pawn. The Python award model tests the
transaction/curve contract; it does NOT execute Pawn or HLDS callbacks.
"""
from pathlib import Path
import re
import sqlite3
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'addons/amxmodx/scripting'
CORE = (SRC / 'ARP_Skills.sma').read_text()
XP = (SRC / 'include/SkillWorks_Progression.inc').read_text()
AUTH = 'STEAM_' + '0:0:1'  # Synthetic identity.
CREATE = re.search(r'RunQuery\("(CREATE TABLE IF NOT EXISTS arp_skills [^"]+)"\)', CORE)[1]

def macro(name):
    return re.search(r'^#define ' + name + r' "([^"]+)"', XP, re.M)[1]

def reward_for(level, required, reward=10, full=10, stop=25):
    gap = level - required
    if gap < 0 or gap >= stop or reward == 0:
        return 0
    return reward if gap <= full else max(1, reward // 2)

def advance(level, xp, base=100, step=5):
    while level < 100 and xp >= base + step * level:
        xp -= base + step * level
        level += 1
    return level, 0 if level == 100 else xp

def initialize(db):
    db.execute(CREATE)
    db.execute(macro('XP_CREATE'))
    db.execute('INSERT OR IGNORE INTO arp_skills (steamid,general) VALUES (?,20)', (AUTH,))

def state(db, skill=0):
    return db.execute(macro('XP_GET') % (AUTH, skill)).fetchone() or (0, 0)

def award(db, now, skill=0, key='general', fail=False, cooldown=30):
    """Reference transaction using the actual SQL; raises to inject a mid-write failure."""
    db.execute('BEGIN IMMEDIATE')
    try:
        level = db.execute(f'SELECT {key} FROM arp_skills WHERE steamid=?', (AUTH,)).fetchone()[0]
        xp, last = state(db, skill)
        if last and (now < last or now-last < cooldown):
            db.execute('ROLLBACK')
            return False
        newlevel, xp = advance(level, xp+10)
        db.execute(macro('LEVEL_PUT') % (key, newlevel, AUTH, key, level))
        if fail:
            raise RuntimeError('injected write failure')
        db.execute(macro('XP_PUT') % (AUTH, skill, xp, now))
        db.execute('COMMIT')
        return True
    except Exception:
        db.execute('ROLLBACK')
        raise

class ProgressionBoundaries(unittest.TestCase):
    def test_reward_difficulty_edges(self):
        self.assertEqual([reward_for(n, 20) for n in (19,20,30,31,44,45,100)], [0,10,10,5,5,0,0])
        self.assertEqual(reward_for(31, 20, reward=1), 1)
        self.assertEqual(reward_for(20, 20, reward=0), 0)
    def test_exact_threshold_and_carry(self):
        self.assertEqual(advance(20,199), (20,199))
        self.assertEqual(advance(20,200), (21,0))
        self.assertEqual(advance(20,209), (21,9))
        self.assertEqual(advance(20,405), (22,0))
    def test_cap_and_extreme_configuration(self):
        self.assertEqual(advance(99,594), (99,594))
        self.assertEqual(advance(99,595), (100,0))
        self.assertEqual(advance(0,10000,1,0), (100,0))
        self.assertLess(100000 + 10000*99 + 1100000 + 10000, 2**31)
    def test_zero_level_beginner_has_no_default_crafting_unlock(self):
        for module in ('General','Cooking','Weapons','Drugs'):
            text=(SRC/f'ARP_{module}.sma').read_text()
            defaults=re.search(r'g_SkillDefaults\[RECIPES\]\[\] = \{([^}]+)', text)[1]
            self.assertTrue(all(int(x)>0 for x in re.findall(r'"(\d+)"', defaults)))

class XPDatabaseContracts(unittest.TestCase):
    def setUp(self):
        self.db=sqlite3.connect(':memory:', isolation_level=None)
        initialize(self.db)
    def tearDown(self): self.db.close()
    def test_additive_table_preserves_old_levels(self):
        before=self.db.execute('SELECT * FROM arp_skills').fetchall()
        schema=self.db.execute('PRAGMA table_info(arp_skills)').fetchall()
        self.db.execute(macro('XP_CREATE'))
        self.assertEqual(self.db.execute('SELECT * FROM arp_skills').fetchall(), before)
        self.assertEqual(self.db.execute('PRAGMA table_info(arp_skills)').fetchall(), schema)
        self.assertEqual(state(self.db), (0,0))
    def test_composite_key_isolates_skills(self):
        for skill in (0,1): self.db.execute(macro('XP_PUT') % (AUTH,skill,10+skill,1000))
        self.assertEqual(state(self.db,0), (10,1000))
        self.assertEqual(state(self.db,1), (11,1000))
    def test_duplicate_completion_and_clock_rollback_no_extra_xp(self):
        self.assertTrue(award(self.db,1000))
        for now in (1000,1001,1029,900): self.assertFalse(award(self.db,now))
        self.assertEqual(state(self.db), (10,1000))
        self.assertTrue(award(self.db,1030))
    def test_failure_rolls_back_level_xp_and_timestamp(self):
        self.db.execute(macro('XP_PUT') % (AUTH,0,195,1000))
        with self.assertRaises(RuntimeError): award(self.db,1030,fail=True)
        self.assertEqual(state(self.db), (195,1000))
        self.assertEqual(self.db.execute('SELECT general FROM arp_skills').fetchone()[0],20)
        self.assertTrue(award(self.db,1030))
        self.assertEqual(state(self.db), (5,1030))
        self.assertEqual(self.db.execute('SELECT general FROM arp_skills').fetchone()[0],21)
    def test_restart_persists_partial_xp_and_cooldown(self):
        with tempfile.TemporaryDirectory() as folder:
            path=str(Path(folder)/'test.sqlite')
            db=sqlite3.connect(path, isolation_level=None);initialize(db)
            award(db,1000);db.close()
            db=sqlite3.connect(path, isolation_level=None)
            self.assertEqual(state(db),(10,1000))
            self.assertFalse(award(db,1029));self.assertTrue(award(db,1030));db.close()
    def test_second_connection_cannot_write_inside_transaction(self):
        with tempfile.TemporaryDirectory() as folder:
            path=str(Path(folder)/'test.sqlite')
            db=sqlite3.connect(path, isolation_level=None);initialize(db)
            other=sqlite3.connect(path, isolation_level=None, timeout=0)
            db.execute('BEGIN IMMEDIATE')
            with self.assertRaises(sqlite3.OperationalError): award(other,1000)
            db.execute('ROLLBACK');self.assertTrue(award(other,1000))
            db.close();other.close()
    def test_admin_reset_preserves_cooldown(self):
        self.db.execute(macro('XP_PUT') % (AUTH,0,195,1000))
        self.db.execute('BEGIN IMMEDIATE')
        self.db.execute(macro('LEVEL_PUT') % ('general',25,AUTH,'general',20))
        self.db.execute(macro('XP_PUT') % (AUTH,0,0,1000))
        self.db.execute('COMMIT')
        self.assertEqual(state(self.db),(0,1000))
        self.assertFalse(award(self.db,1001))

class HookContracts(unittest.TestCase):
    def test_only_successful_practical_modules_have_award_hook(self):
        for module in ('General','Weapons','Drugs','Cooking','Computers'):
            text=(SRC/f'ARP_{module}.sma').read_text()
            self.assertEqual(text.count('SW_AwardXP('),1,module)
            self.assertIn('g_Active[id] = 0', text[:text.index('SW_AwardXP(')])
        for module in ('Fighting','Law'):
            self.assertNotIn('SW_AwardXP(', (SRC/f'ARP_{module}.sma').read_text())
    def test_transaction_and_owner_guards_are_present(self):
        self.assertIn('g_ActOwner[a] != plugin', XP)
        self.assertIn('!g_ActPractice[a]', XP)
        self.assertIn('if (g_Lesson[id])', XP)
        self.assertIn('SaveLevel(auth, skill, values[skill], value, true)', CORE)
        self.assertIn('SaveLevel(auth, skill, oldValue, oldValue + gain, false)', CORE)
    def test_unlock_registry_uses_live_availability_and_thresholds(self):
        self.assertIn('ActivityAvailable(a, required)',XP)
        self.assertIn('SW_ReadInt(g_ActRequired[a], 0, 100, required)',XP)
        for module in ('General','Weapons','Drugs','Cooking','Computers','Fighting','Law'):
            text=(SRC/f'ARP_{module}.sma').read_text()
            self.assertIn('SW_RegisterActivity(',text)
            self.assertIn('public SW_ActivityAvailable(',text)
        self.assertIn('return job && SafeJobAccess(job);',(SRC/'ARP_Law.sma').read_text())

if __name__ == '__main__': unittest.main()
