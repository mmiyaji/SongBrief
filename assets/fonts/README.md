# SongBrief Web UI font

A subset of Noto Sans JP used only as a fallback by Flutter Web. iOS/Android/desktop keep system fonts and do not package this directory. Latin text keeps the existing Roboto/default face.

Source: https://github.com/google/fonts/tree/main/ofl/notosansjp
Downloaded 2026-11-15: `NotoSansJP[wght].ttf`, Google Fonts blob `cdd8f083c1f5928ff3361f8cda4d3fc9462cbe89`.
Source SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`.

`SongBriefUI.woff2` contains the supported characters occurring in `lib/**/*.dart`, Latin, Japanese kana, punctuation, full-width forms and date/number units. It retains variable weights. Library titles using other characters continue to use the existing system/engine fallback.

Regenerate after adding UI translations or changing localized text:

```sh
python tool/build_web_font.py path/to/NotoSansJP-source.ttf
```

The generator requires fontTools and Brotli and verifies the pinned source hash and character coverage. These are authoring tools, not runtime dependencies; normal Flutter builds use the checked-in font. The Web bootstrap registers the font before runApp, in parallel with preferences/analytics initialization, so app labels do not trigger many late CJK font downloads and relayouts.

The original copyright notice and SIL Open Font License are in `OFL-NotoSansJP.txt` and registered with Flutter's license registry on Web. This is a modified (subset/compressed) font, not the complete upstream distribution.
