"""Build the bundled Web UI font from the pinned Noto Sans JP source.

Usage: python tool/build_web_font.py path/to/NotoSansJP-source.ttf
Requires fontTools[woff] and Brotli. Not needed for normal Flutter builds.
"""
from pathlib import Path
import hashlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
expected = 'c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f'
if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
    raise SystemExit('Unexpected source font; inspect and update the pinned hash first')

codepoints = set(range(0x20, 0x250))
for start, end in [(0x2000, 0x2070), (0x3000, 0x3100), (0xFF00, 0xFFF0)]:
    codepoints.update(range(start, end))
codepoints.update(map(ord, '日月火水木金土年月午前後一二三四五六七八九十百千万億兆'))
for path in (root / 'lib').rglob('*.dart'):
    codepoints.update(map(ord, path.read_text(encoding='utf-8')))

font = TTFont(source, recalcTimestamp=False)
available = set(font.getBestCmap())
options = subset.Options()
options.layout_features = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=codepoints & available)
subsetter.subset(font)
font.flavor = 'woff2'
destination = root / 'assets/fonts/SongBriefUI.woff2'
font.save(destination)
check = TTFont(destination)
assert codepoints & available <= set(check.getBestCmap())
print(f'{destination.name}: {destination.stat().st_size} bytes, {len(check.getBestCmap())} characters')
