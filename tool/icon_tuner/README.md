# SongBrief Icon Tuner

Local-only browser UI for small icon adjustments.

```powershell
node tool/icon_tuner/server.mjs 5174
```

Open `http://127.0.0.1:5174/`.

The Save button updates:

- `assets/branding/songbrief_icon.png`
- `assets/branding/songbrief_icon_foreground.png`
- `tool/icon_tuner/icon_params.json`

The regenerate button runs:

- `dart run flutter_launcher_icons`
- `dart run flutter_native_splash:create`
