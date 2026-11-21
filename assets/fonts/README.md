# Inter Tight (subset)

The `InterTight-{Light,Regular,Medium,SemiBold}.ttf` files here are subsets
of Inter Tight, Copyright 2022 The Inter Project Authors
(https://github.com/rsms/inter-tight). They remain under the SIL Open Font
License 1.1 (`OFL.txt`). The licence declares no Reserved Font Name, so the
modified (subset) fonts keep their original names.

The subsets keep Basic Latin, Latin-1, Latin Extended-A, the Romanian comma
letters, general punctuation, the fraction glyphs (⅓ ½ and the other
U+2150–215F that Inter Tight has), the fraction slash ⁄ (U+2044), arrows
(← ↑ → ↓) and the symbols the UI draws (− ≈ ▲ ▼ ● € ™). Hinting is dropped.
The layout features are kept, `frac` among them.

Inter Tight has no ⅔ (U+2154). So the UI never draws the glyphs: stop
labels show a third or a half as digits around the fraction slash (`2⁄3`)
in a span of its own with `FontFeature.fractions()`
(`lib/ui/stops_text.dart`). The ⅓ ⅔ ½ strings stay as the data format
(exports, screen-reader labels). Anything outside
the subset, such as Cyrillic or Greek text in a roll's notes, falls back to
the system font.

## Regenerating

The unmodified fonts are in `tool/fonts/source/`. Run `tool/fonts/subset.sh`
(needs fontTools; the script's header says how to install it). It rewrites
the files here and fails if a character the UI uses, and that Inter Tight
has, is missing from a subset.
