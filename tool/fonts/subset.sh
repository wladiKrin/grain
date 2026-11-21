#!/usr/bin/env bash
# Subsets the Inter Tight sources in tool/fonts/source/ into assets/fonts/
# (same file names), keeping Latin, Latin-1, Latin Extended-A, the Romanian
# comma letters, general punctuation, fractions and the fraction slash (U+2044,
# which the UI draws stop thirds and halves with), arrows and the few symbols
# the UI draws. Then checks that every UI glyph the source font had survived.
#
# Made with fontTools 4.68.0 (pyftsubset). It installs nothing; to get it:
#   python3 -m venv ~/.local/share/grain-fonttools && ~/.local/share/grain-fonttools/bin/pip install fonttools
# Run from anywhere: tool/fonts/subset.sh
set -euo pipefail

cd "$(dirname "$0")/../.."

venv="$HOME/.local/share/grain-fonttools/bin"
if command -v pyftsubset >/dev/null 2>&1; then
  pyftsubset="$(command -v pyftsubset)"
elif [ -x "$venv/pyftsubset" ]; then
  pyftsubset="$venv/pyftsubset"
else
  echo "pyftsubset not found. Install fontTools in a venv:" >&2
  echo "  python3 -m venv ~/.local/share/grain-fonttools && ~/.local/share/grain-fonttools/bin/pip install fonttools" >&2
  exit 1
fi
python="$(dirname "$pyftsubset")/python3"
[ -x "$python" ] || python=python3

for src in tool/fonts/source/InterTight-*.ttf; do
  "$pyftsubset" "$src" --output-file="assets/fonts/$(basename "$src")" --unicodes="U+0020-007E,U+00A0-017F,U+0218-021B,U+2010-2027,U+2030,U+2032-2033,U+2039-203A,U+2044,U+20AC,U+2122,U+2150-215F,U+2190-2193,U+2212,U+2248,U+25B2,U+25BC,U+25CF" --layout-features='*' --no-hinting --desubroutinize
  echo "$(basename "$src"): $(stat -c %s "$src") -> $(stat -c %s "assets/fonts/$(basename "$src")") bytes"
done

# The check: the fixed UI list plus every non-ASCII character in lib/ outside
# comments. A glyph the source font has but the subset lacks fails the run; a
# glyph Inter Tight never had falls back to the system font and is reported.
"$python" -I - tool/fonts/source lib <<'PY'
import pathlib, re, sys
from fontTools.ttLib import TTFont

src_dir, lib_dir = map(pathlib.Path, sys.argv[1:3])
wanted = set("→←·−…—–×±⅓⅔½≈▲▼●äöüßéñ\u2044")
for path in lib_dir.rglob('*.dart'):
    for line in path.read_text(encoding='utf-8').splitlines():
        code = line.split('//', 1)[0]
        wanted.update(ch for ch in code if ord(ch) > 0x7E)
        wanted.update(chr(int(h, 16)) for h in re.findall(r'\\u([0-9A-Fa-f]{4})', code)
                      if int(h, 16) >= 0xA0 and int(h, 16) != 0xFEFF)

failed = False
for src in sorted(src_dir.glob('InterTight-*.ttf')):
    have = TTFont(src).getBestCmap()
    sub = TTFont(pathlib.Path('assets/fonts') / src.name).getBestCmap()
    for ch in sorted(wanted):
        cp = ord(ch)
        if cp in have and cp not in sub:
            print(f'MISSING {src.name}: U+{cp:04X} {ch}')
            failed = True
        elif cp not in have:
            print(f'fallback {src.name}: U+{cp:04X} {ch} (not in Inter Tight)')
print(f'checked {len(wanted)} characters')
sys.exit(1 if failed else 0)
PY
