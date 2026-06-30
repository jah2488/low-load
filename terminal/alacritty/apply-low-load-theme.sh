#!/usr/bin/env bash
# apply-low-load-theme.sh
# Applies a cognitive-load + dyslexia-friendly Alacritty theme, derived from the
# research audit of the Low Load writing style. Idempotent and re-runnable.
#
# What it does (all local to this machine):
#   1. Installs the chosen font (direct download into ~/Library/Fonts) if missing.
#      Homebrew casks are avoided on purpose — the font casks we tried stall for
#      minutes on slow upstream hosts.
#   2. Detects the exact family name the system registered (no guessing).
#   3. Writes ~/.config/alacritty/themes/low-load.toml.
#   4. Backs up alacritty.toml and wires in the theme import.
#   5. Validates the result with Alacritty's own parser.
# Alacritty live-reloads config on save; font swaps may need a fresh window.
#
# To change the font later: edit the FONT block below (family match, fallback,
# base URL, file list). Everything else stays. A terminal can't enforce line
# length or paragraph spacing — those live in the Low Load *writing* style.

set -euo pipefail

# --- FONT (edit this block to swap fonts) -----------------------------------
FONT_MATCH="jetbrains"          # case-insensitive substring to find it on the system
FALLBACK_FAMILY="JetBrains Mono"  # used if system lookup comes back empty
FONT_BASE="https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf"
FONT_FILES=(
  JetBrainsMono-Regular.ttf
  JetBrainsMono-Bold.ttf
  JetBrainsMono-Italic.ttf
  JetBrainsMono-BoldItalic.ttf
)
FONT_SIZE=14.0
HAS_BOLD_ITALIC=1               # 1 if the font ships real bold/italic faces

# --- paths ------------------------------------------------------------------
CONF_DIR="$HOME/.config/alacritty"
THEME_DIR="$CONF_DIR/themes"
THEME="$THEME_DIR/low-load.toml"
CONF="$CONF_DIR/alacritty.toml"

say(){ printf '%s\n' "$*"; }
family_on_system(){
  system_profiler SPFontsDataType 2>/dev/null \
    | sed -n 's/^[[:space:]]*Family:[[:space:]]*//p' | sort -u \
    | grep -i "$FONT_MATCH" | head -1
}

mkdir -p "$THEME_DIR" "$HOME/Library/Fonts"

# 1. Font (direct download, no brew) -----------------------------------------
if [ -n "$(family_on_system)" ]; then
  say "font: '$FONT_MATCH' already installed"
else
  say "font: downloading ${#FONT_FILES[@]} face(s) …"
  for f in "${FONT_FILES[@]}"; do
    if curl -fsSL --max-time 60 -o "$HOME/Library/Fonts/$f" "$FONT_BASE/$f"; then
      say "  installed $f"
    else
      say "  FAILED $f — get it manually from $FONT_BASE"
    fi
  done
fi

# 2. Resolve the exact registered family (verify, don't assume) --------------
FAMILY="$(family_on_system)"
[ -z "$FAMILY" ] && FAMILY="$FALLBACK_FAMILY"
say "font family resolved to: $FAMILY"

# 3. Theme -------------------------------------------------------------------
{
cat <<EOF
# Low-Load theme for Alacritty — cognitive-load friendly.
# Auto-written by apply-low-load-theme.sh. Edit that script, not this file.
# Rationale per the research audit: legible font, comfortable size, generous
# leading, gentle (non-halation) contrast, steady cursor, breathing-room padding,
# bold rendered as weight not color.

[font]
size = $FONT_SIZE

[font.normal]
family = "$FAMILY"
style = "Regular"
EOF

if [ "$HAS_BOLD_ITALIC" = "1" ]; then
cat <<EOF

[font.bold]
family = "$FAMILY"
style = "Bold"

[font.italic]
family = "$FAMILY"
style = "Italic"
EOF
fi

cat <<EOF

# Extra vertical leading (~1.3 line height) reduces line-blending.
[font.offset]
x = 0
y = 5

[window]
dynamic_padding = true
opacity = 1.0

# Padding gives text room to breathe and eases place-finding after an interruption.
[window.padding]
x = 18
y = 16

# Steady block cursor: easy to locate, no blink distraction.
[cursor]
unfocused_hollow = true

[cursor.style]
shape = "Block"
blinking = "Off"

[colors]
# Bold stays a weight, not a color shift (research: prefer bold over color/italics).
draw_bold_text_with_bright_colors = false

# Off-black bg + warm off-white fg — avoids the pure #000/#fff halation that
# strains tired / dyslexic / low-vision reading, while keeping high (~12:1) contrast.
[colors.primary]
background = "#1e1e22"
foreground = "#d6d3cd"

[colors.cursor]
text   = "#1e1e22"
cursor = "#e8b339"

[colors.normal]
black   = "#2a2a2f"
red     = "#e06c75"
green   = "#8cc265"
yellow  = "#e5c07b"
blue    = "#61afef"
magenta = "#c678dd"
cyan    = "#56b6c2"
white   = "#d6d3cd"

[colors.bright]
black   = "#5c6370"
red     = "#e06c75"
green   = "#8cc265"
yellow  = "#e5c07b"
blue    = "#61afef"
magenta = "#c678dd"
cyan    = "#56b6c2"
white   = "#efeae3"
EOF
} > "$THEME"
say "theme: wrote $THEME"

# 4. Wire the import idempotently --------------------------------------------
[ -f "$CONF" ] || printf '\n' > "$CONF"
if grep -qF "low-load.toml" "$CONF"; then
  say "import: already wired"
elif grep -qE '^\s*import\s*=' "$CONF"; then
  say "import: an 'import' key already exists in $CONF — add this path to it manually:"
  say "          \"$THEME\""
elif grep -qE '^\s*\[general\]' "$CONF"; then
  say "import: a [general] table exists — add this line under it manually:"
  say "          import = [\"$THEME\"]"
else
  cp "$CONF" "$CONF.bak.$(date +%Y%m%d-%H%M%S)"
  say "import: backed up existing config, prepending [general] import block"
  tmp="$(mktemp)"
  { printf '[general]\nimport = ["%s"]\n\n' "$THEME"; cat "$CONF"; } > "$tmp"
  mv "$tmp" "$CONF"
fi

# 5. Validate with Alacritty's own parser ------------------------------------
ALA="/Applications/Alacritty.app/Contents/MacOS/alacritty"
if [ -x "$ALA" ]; then
  if "$ALA" migrate --dry-run -c "$CONF" >/dev/null 2>&1; then
    say "config: Alacritty parsed it cleanly"
  else
    say "config: Alacritty reported a problem — run: $ALA migrate --dry-run -c \"$CONF\""
  fi
fi

# Bump the main config's mtime so live-reload fires even when only the imported
# theme changed (Alacritty watches the primary config, not imported files).
touch "$CONF"

say "done. Live-reload triggered; open windows update in place."
