# Low Load for iTerm2

iTerm2 splits its settings: colors import from a file, but font, cursor, and
padding live in the profile UI. Two steps.

## 1. Colors (one click)

Double-click `LowLoad.itermcolors`, or import it manually:

`iTerm2 → Settings → Profiles → Colors → Color Presets… → Import…`, pick
`LowLoad.itermcolors`, then select **LowLoad** from the same Color Presets menu.

## 2. Font, cursor, padding (match the other terminals)

The installer prints these; set them once under `Settings → Profiles`:

- **Text → Font**: JetBrains Mono, size 14. Install the font first from
  <https://www.jetbrains.com/lp/mono/> if you don't have it.
- **Text → Cursor**: Box, and uncheck **Blinking cursor** (steady block, no blink).
- **Appearance → Panes → Side/Top margin**: 18 / 16 for breathing room.

The colors avoid pure black/white to cut halation, keep ~12:1 contrast, and render
bold as weight rather than a brighter color. That last one is automatic with this
preset.
