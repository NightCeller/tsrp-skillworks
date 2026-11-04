import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('check_package',ROOT/'tools/check_package.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class DistributionChecks(unittest.TestCase):
    def test_current_package(self): self.assertEqual(module.validate(ROOT),[])
    def test_private_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            (root/'users.ini').write_text('; synthetic, contains no accounts\n')
            errors=module.validate(root)
            self.assertTrue(any('users.ini: outside' in e for e in errors))
    def test_script_in_config_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);p=root/'addons/amxmodx/configs/arp/skills.cfg'
            p.parent.mkdir(parents=True)
            p.write_text('exec unexpected.cfg\n')
            self.assertTrue(any('unsupported executable' in e for e in module.validate(root)))

if __name__ == '__main__':unittest.main()
