# Inter Tight (subset)

The `InterTight-{Light,Regular,Medium,SemiBold}.ttf` files here are subsets
of Inter Tight, Copyright 2022 The Inter Project Authors
(https://github.com/rsms/inter-tight). They remain under the SIL Open Font
License 1.1 (`OFL.txt`). The licence declares no Reserved Font Name, so the
modified (subset) fonts keep their original names.

The subsets keep Basic Latin, Latin-1, Latin Extended-A, the Romanian comma
letters, general punctuation, fractions (⅓ ⅔ ½), arrows (← ↑ → ↓) and the
symbols the UI draws (− ≈ ▲ ▼ ● € ™). Hinting is dropped. Anything outside
the subset, such as Cyrillic or Greek text in a roll's notes, falls back to
the system font.

## Regenerating

The unmodified fonts are in `tool/fonts/source/`. Run `tool/fonts/subset.sh`
(needs fontTools; the script's header says how to install it). It rewrites
the files here and fails if a character the UI uses, and that Inter Tight
has, is missing from a subset.
