"""Writes lib/l10n/app_km.arb from tool/km_strings.py and checks it matches
app_en.arb (same keys, same placeholders)."""
import json, re, sys, collections
sys.path.insert(0, 'tool')
from km_strings import KM

en = json.load(open('lib/l10n/app_en.arb'), object_pairs_hook=collections.OrderedDict)
keys = [k for k in en if not k.startswith('@') and k != '@@locale']

def placeholders(text):
    # {name} and the first argument of {name, plural, ...}
    return set(re.findall(r'\{(\w+)(?:,|\})', text))

missing = [k for k in keys if k not in KM]
extra = [k for k in KM if k not in keys]
bad = [k for k in keys if k in KM and placeholders(en[k]) != placeholders(KM[k])]
if missing or extra or bad:
    print('missing:', missing); print('extra:', extra); print('placeholder mismatch:', bad)
    sys.exit(1)

out = collections.OrderedDict([('@@locale', 'km')])
for k in keys:
    out[k] = KM[k]
json.dump(out, open('lib/l10n/app_km.arb', 'w'), indent=2, ensure_ascii=False)
open('lib/l10n/app_km.arb', 'a').write('\n')
print('wrote', len(keys), 'strings')
