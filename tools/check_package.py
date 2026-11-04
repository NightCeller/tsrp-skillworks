"""Check the source-distribution boundary. Not a comprehensive secrets audit."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MODULES = ('Skills','Cooking','Computers','Weapons','General','Drugs','Fighting','Law')
SOURCES = {f'addons/amxmodx/scripting/ARP_{n}.sma' for n in MODULES}
CONFIGS = {f'addons/amxmodx/configs/arp/{n.lower()}.cfg' for n in MODULES}
EXACT = {'README.md','LICENSE','NOTICE','VERSION','CHANGELOG.md','ROADMAP.md',
         'CONTRIBUTING.md','SECURITY.md','.gitignore','.gitattributes',
         'examples/plugins-skillworks.ini','SHA256SUMS.txt'}
PREFIXES = ('docs/','tools/','tests/','.github/')
TEXT_SUFFIXES = {'.md','.py','.ps1','.sh','.json','.yml','.yaml'}
PATTERNS = {
    'Steam ID': r'STEAM_[0-9]+:[0-9]+:[0-9]+',
    'IPv4 address': r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])',
    'GitHub token': r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})',
    'private key': r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'credential URL': r'https?://[^\s/:]+:[^\s/@]+@',
    'home path': r'(?:[A-Za-z]:\\Users\\|/home/|/Users/)[A-Za-z0-9_.-]+',
}

def validate(root=ROOT):
    errors = []
    present = set()
    for p in sorted(root.rglob('*')):
        rel = p.relative_to(root).as_posix()
        if any(part in {'.git','build','__pycache__'} for part in p.relative_to(root).parts):
            continue
        if p.is_symlink():
            errors.append(f'{rel}: symlink not allowed'); continue
        if not p.is_file(): continue
        present.add(rel)
        allowed = rel in SOURCES | CONFIGS | EXACT or (rel.startswith(PREFIXES) and p.suffix in TEXT_SUFFIXES)
        if not allowed:
            errors.append(f'{rel}: outside public source allowlist'); continue
        try: text = p.read_text(encoding='utf-8')
        except UnicodeError:
            errors.append(f'{rel}: non-text content'); continue
        for kind, pattern in PATTERNS.items():
            if re.search(pattern, text): errors.append(f'{rel}: potential {kind} (value withheld)')
        if rel in CONFIGS:
            for line in text.splitlines():
                line = line.strip()
                if not line or line.startswith('//'): continue
                if not re.fullmatch(r'arp_(?:skills|cooking|hack|weapons|general|drugs|fighting|law)_[a-z0-9_]+\s+"?\d+"?', line):
                    errors.append(f'{rel}: unsupported executable config line')
    for rel in SOURCES | CONFIGS | {'LICENSE','NOTICE','README.md','VERSION'}:
        if rel not in present: errors.append(f'{rel}: required file missing')
    return errors

if __name__ == '__main__':
    failures = validate()
    for failure in failures: print(failure, file=sys.stderr)
    print(f'Package checks: {len(failures)} issue(s). Build outputs are excluded from this source check.')
    sys.exit(bool(failures))
