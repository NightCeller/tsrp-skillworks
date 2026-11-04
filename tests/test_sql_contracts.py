"""SQLite contract tests using statements extracted from the shipped Pawn source.
These do not execute Pawn callbacks or simulate HLDS.
"""
import re
import sqlite3
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'addons/amxmodx/scripting'
SKILLS = (SOURCE / 'ARP_Skills.sma').read_text()
COMPUTERS = (SOURCE / 'ARP_Computers.sma').read_text()
CREATE = re.search(r'RunQuery\("(CREATE TABLE IF NOT EXISTS arp_skills [^"]+)"\)', SKILLS)[1]
LESSON = re.search(r'"(UPDATE arp_skills SET %s=%d WHERE steamid=\'%s\' AND %s=%d)"', SKILLS)[1]
def macro(name):
    return re.search(r'^#define '+name+r' "([^"]+)"', COMPUTERS, re.M)[1]
AUTH = 'STEAM_' + '0:0:1'  # Synthetic fixture, never a real server account.

class SkillsContracts(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute(CREATE)
        self.db.execute('INSERT INTO arp_skills (steamid) VALUES (?)', (AUTH,))
    def tearDown(self): self.db.close()
    def test_all_defaults_zero_and_duplicate_identity_rejected(self):
        row = self.db.execute('SELECT * FROM arp_skills').fetchone()
        self.assertEqual(row, (AUTH,0,0,0,0,0,0,0))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO arp_skills (steamid) VALUES (?)', (AUTH,))
    def test_lesson_cannot_overwrite_concurrent_admin_edit(self):
        self.db.execute('UPDATE arp_skills SET general=20 WHERE steamid=?', (AUTH,))
        stale = LESSON % ('general',1,AUTH,'general',0)
        self.assertEqual(self.db.execute(stale).rowcount, 0)
        self.assertEqual(self.db.execute('SELECT general FROM arp_skills').fetchone()[0],20)
    def test_conditional_lesson_award_is_single_use(self):
        statement = LESSON % ('general',1,AUTH,'general',0)
        self.assertEqual(self.db.execute(statement).rowcount, 1)
        self.assertEqual(self.db.execute(statement).rowcount, 0)
    def test_all_addon_selects_use_same_schema(self):
        for path in SOURCE.glob('ARP_*.sma'):
            for column in re.findall(r'SELECT (\w+) FROM arp_skills',path.read_text()):
                self.assertEqual(self.db.execute(f'SELECT {column} FROM arp_skills').fetchone()[0],0)

class CooldownContracts(unittest.TestCase):
    def test_two_key_rollback_and_reopen(self):
        with tempfile.TemporaryDirectory() as d:
            path = str(Path(d)/'fixture.sqlite')
            db = sqlite3.connect(path, isolation_level=None)
            db.execute(macro('SQL_CREATE'))
            player, atm = 'P:'+AUTH, 'A:test_map:0:0:0'
            db.execute('BEGIN IMMEDIATE')
            db.execute(macro('SQL_PUT') % (player,12345))
            # Failed/interrupted reservation must be able to undo its first write.
            db.execute('ROLLBACK')
            self.assertIsNone(db.execute(macro('SQL_GET')%player).fetchone())
            db.execute('BEGIN IMMEDIATE')
            for key in (player,atm): db.execute(macro('SQL_PUT')%(key,12345))
            db.execute('COMMIT'); db.close()
            db = sqlite3.connect(path)
            for key in (player,atm): self.assertEqual(db.execute(macro('SQL_GET')%key).fetchone()[0],12345)
            db.close()

if __name__ == '__main__': unittest.main()
