#!/usr/bin/env bash
# Low Load installer — pick the pieces you want, see what your system supports,
# install only what you choose. Safe to re-run: it backs up settings.json and
# never overwrites your other hooks.
#
#   curl -fsSL https://raw.githubusercontent.com/jah2488/low-load/main/install.sh | bash
#   # or, from a clone:  ./install.sh
#
# Works on bash 3.2+ (the macOS default). Reads choices from /dev/tty so it stays
# interactive even when piped from curl. With no terminal, it installs the
# recommended defaults and reports what it did.

set -euo pipefail

REPO="jah2488/low-load"
BRANCH="main"
REPO_RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

# ---------- presentation ----------------------------------------------------
if [ -t 1 ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
  GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; CYN=$'\033[36m'; BLU=$'\033[34m'
else
  B=""; D=""; R=""; GRN=""; YEL=""; RED=""; CYN=""; BLU=""
fi
ok()   { printf '%s✓%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '%s⚠%s %s\n' "$YEL" "$R" "$*"; }
bad()  { printf '%s✗%s %s\n' "$RED" "$R" "$*"; }
info() { printf '%s·%s %s\n' "$D" "$R" "$*"; }
head2(){ printf '\n%s%s%s\n' "$B" "$*" "$R"; }
rule() { printf '%s────────────────────────────────────────────────────────%s\n' "$D" "$R"; }

banner() {
  printf '\n'
  printf '%s  ▟ Low Load%s   %sClaude Code, tuned for tired eyes%s\n' "$CYN" "$R" "$D" "$R"
  printf '%s  less to read · less to track · less to strain%s\n' "$D" "$R"
  rule
}

# ---------- interactivity ----------------------------------------------------
INTERACTIVE=0
if { : >/dev/tty; } 2>/dev/null; then INTERACTIVE=1; fi
ask() { # ask "<prompt>" -> echoes the line the user typed (empty if non-interactive)
  local prompt="$1" reply=""
  if [ "$INTERACTIVE" = 1 ]; then
    printf '%s' "$prompt" > /dev/tty
    IFS= read -r reply < /dev/tty || reply=""
  fi
  printf '%s' "$reply"
}

# ---------- source files (local clone or download) --------------------------
SELF="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR=""
if [ -f "$SELF" ]; then SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"; fi
LOCAL_MODE=0
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/claude/output-styles/low-load.md" ]; then LOCAL_MODE=1; fi
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fetch() { # fetch <relpath> -> prints an absolute path to a readable copy
  local rel="$1"
  if [ "$LOCAL_MODE" = 1 ]; then printf '%s' "$SCRIPT_DIR/$rel"; return 0; fi
  local dest="$WORK/$rel"
  mkdir -p "$(dirname "$dest")"
  if ! curl -fsSL "$REPO_RAW/$rel" -o "$dest"; then
    bad "could not download $rel" >&2; return 1
  fi
  printf '%s' "$dest"
}

# ---------- capability detection ("what can this system handle?") -----------
have() { command -v "$1" >/dev/null 2>&1; }
OS="$(uname -s)"
IS_MAC=0; [ "$OS" = "Darwin" ] && IS_MAC=1

HAS_JQ=0;     have jq && HAS_JQ=1
HAS_CURL=0;   have curl && HAS_CURL=1
HAS_CLAUDE=0; [ -d "$CLAUDE_DIR" ] && HAS_CLAUDE=1

term_alacritty=0; { have alacritty || [ -d /Applications/Alacritty.app ]; } && term_alacritty=1
term_ghostty=0;   { have ghostty   || [ -d /Applications/Ghostty.app ];   } && term_ghostty=1
term_iterm=0;     [ "$IS_MAC" = 1 ] && [ -d /Applications/iTerm.app ] && term_iterm=1
TERM_COUNT=$((term_alacritty + term_ghostty + term_iterm))

print_capabilities() {
  head2 "Checking what your system can handle"
  if [ "$IS_MAC" = 1 ]; then ok "macOS detected"; else info "OS: $OS (sound cues are macOS-only)"; fi
  [ "$HAS_CLAUDE" = 1 ] && ok "Claude Code config at $CLAUDE_DIR" || warn "no $CLAUDE_DIR yet — it'll be created (install Claude Code if you haven't)"
  [ "$HAS_JQ" = 1 ] && ok "jq present (needed to edit settings safely)" || warn "jq missing — output style, status line and sound cues need it (brew install jq)"
  if [ "$TERM_COUNT" -gt 0 ]; then
    local list=""
    [ "$term_alacritty" = 1 ] && list="$list Alacritty"
    [ "$term_ghostty" = 1 ]   && list="$list Ghostty"
    [ "$term_iterm" = 1 ]     && list="$list iTerm2"
    ok "terminal theme available for:$list"
  else
    info "no supported terminal found (Alacritty / Ghostty / iTerm2) — theme will be skipped"
  fi
}

# ---------- component model (parallel arrays; bash 3.2 safe) ----------------
# keys: style statusline render sound theme
C_KEY=();   C_LABEL=();  C_DESC=();  C_AVAIL=(); C_REASON=(); C_SEL=()
add_comp() { # key label desc avail reason default
  C_KEY+=("$1"); C_LABEL+=("$2"); C_DESC+=("$3"); C_AVAIL+=("$4"); C_REASON+=("$5"); C_SEL+=("$6")
}

avail_settings=$([ "$HAS_JQ" = 1 ] && echo 1 || echo 0)
add_comp style      "Output style (Low Load)" \
  "Answer-first, terse, scannable replies. The core change." \
  "$avail_settings" "needs jq" "$avail_settings"
add_comp statusline "Status line" \
  "One glanceable bar: model, context %, rate limit, branch. No cost shown." \
  "$avail_settings" "needs jq" "$avail_settings"
add_comp render     "render skill" \
  "Moves long plans/tables/forms out of the terminal into a clean local web page." \
  1 "" 1
SOUND_AVAIL=$([ "$IS_MAC" = 1 ] && [ "$HAS_JQ" = 1 ] && echo 1 || echo 0)
SOUND_REASON="macOS + jq only"
add_comp sound      "Sound cues" \
  "A soft chime when Claude needs you, another when it finishes. Monitor by ear." \
  "$SOUND_AVAIL" "$SOUND_REASON" "$SOUND_AVAIL"
THEME_AVAIL=$([ "$TERM_COUNT" -gt 0 ] && echo 1 || echo 0)
THEME_DEFAULT=$([ "$TERM_COUNT" -gt 0 ] && echo 1 || echo 0)
add_comp theme      "Terminal theme" \
  "Dyslexia-friendly typography: JetBrains Mono, generous leading, gentle contrast, steady cursor." \
  "$THEME_AVAIL" "no supported terminal" "$THEME_DEFAULT"
add_comp flint      "flint mode (recommended companion)" \
  "Optional plugin. One mode that makes Claude build less, say less, claim less. Pairs with Low Load." \
  "$avail_settings" "needs jq" "$avail_settings"

N=${#C_KEY[@]}

render_menu() {
  head2 "Choose what to install"
  info "the output style alone is most of the benefit; the rest is gravy"
  info "flint is optional but worth it — it makes Claude do less, not just say less"
  printf '\n'
  local i
  for i in $(seq 0 $((N-1))); do
    local n=$((i+1)) mark
    if [ "${C_AVAIL[$i]}" != 1 ]; then
      printf '  %s%d.%s %s[ ]%s %s%s%s %s(%s)%s\n' \
        "$D" "$n" "$R" "$D" "$R" "$D" "${C_LABEL[$i]}" "$R" "$D" "${C_REASON[$i]}" "$R"
    else
      if [ "${C_SEL[$i]}" = 1 ]; then mark="${GRN}[x]${R}"; else mark="[ ]"; fi
      printf '  %s%d.%s %s %s%s%s\n' "$B" "$n" "$R" "$mark" "$B" "${C_LABEL[$i]}" "$R"
    fi
    printf '       %s%s%s\n' "$D" "${C_DESC[$i]}" "$R"
  done
  printf '\n'
}

toggle() { # toggle one index if available
  local i="$1"
  [ "${C_AVAIL[$i]}" != 1 ] && { warn "${C_LABEL[$i]} isn't available here (${C_REASON[$i]})"; return; }
  if [ "${C_SEL[$i]}" = 1 ]; then C_SEL[$i]=0; else C_SEL[$i]=1; fi
}

select_components() {
  if [ "$INTERACTIVE" != 1 ]; then
    render_menu
    warn "no terminal for input — installing the recommended defaults above"
    return
  fi
  while :; do
    render_menu
    local reply
    reply="$(ask "${CYN}toggle a number, [a]ll, [n]one, Enter to install, [q]uit:${R} ")"
    case "$reply" in
      "" ) break ;;
      q|Q ) info "cancelled, nothing changed"; exit 0 ;;
      a|A ) local i; for i in $(seq 0 $((N-1))); do [ "${C_AVAIL[$i]}" = 1 ] && C_SEL[$i]=1; done ;;
      n|N ) local i; for i in $(seq 0 $((N-1))); do C_SEL[$i]=0; done ;;
      *  )
        local tok
        for tok in $reply; do
          case "$tok" in
            *[!0-9]* ) warn "ignored '$tok'" ;;
            * ) if [ "$tok" -ge 1 ] && [ "$tok" -le "$N" ]; then toggle $((tok-1)); else warn "no item $tok"; fi ;;
          esac
        done ;;
    esac
  done
}

is_sel() { # is_sel <key> -> 0/1 via return code
  local k="$1" i
  for i in $(seq 0 $((N-1))); do
    if [ "${C_KEY[$i]}" = "$k" ] && [ "${C_SEL[$i]}" = 1 ] && [ "${C_AVAIL[$i]}" = 1 ]; then return 0; fi
  done
  return 1
}

# ---------- settings.json helpers (jq, atomic, backed up) -------------------
SETTINGS_BACKED_UP=0
ensure_settings() {
  mkdir -p "$CLAUDE_DIR"
  [ -s "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
  if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
    bad "$SETTINGS is not valid JSON — fix or move it, then re-run"; exit 1
  fi
  if [ "$SETTINGS_BACKED_UP" = 0 ]; then
    cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
    SETTINGS_BACKED_UP=1
  fi
}
jq_set() { # jq_set <filter> [--arg ...]
  local filter="$1"; shift
  local tmp; tmp="$(mktemp)"
  jq "$@" "$filter" "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
}
append_hook() { # append_hook <event> <command> (idempotent)
  jq_set '
    .hooks //= {} | .hooks[$ev] //= [] |
    if ([.hooks[$ev][]?.hooks[]?.command] | index($cmd)) != null then .
    else .hooks[$ev] += [{matcher:"", hooks:[{type:"command", command:$cmd}]}] end
  ' --arg ev "$1" --arg cmd "$2"
}

# ---------- per-component install -------------------------------------------
install_style() {
  ensure_settings
  mkdir -p "$CLAUDE_DIR/output-styles"
  cp "$(fetch claude/output-styles/low-load.md)" "$CLAUDE_DIR/output-styles/low-load.md"
  jq_set '.outputStyle = "Low Load"'
  ok "output style installed (set outputStyle = \"Low Load\")"
}
install_statusline() {
  ensure_settings
  cp "$(fetch claude/statusline.sh)" "$CLAUDE_DIR/statusline.sh"
  chmod +x "$CLAUDE_DIR/statusline.sh"
  jq_set '.statusLine = {type:"command", command:"~/.claude/statusline.sh"}'
  ok "status line installed"
  have jq || warn "the status line itself also calls jq at runtime"
}
install_render() {
  mkdir -p "$CLAUDE_DIR/skills/render/templates"
  cp "$(fetch claude/skills/render/SKILL.md)" "$CLAUDE_DIR/skills/render/SKILL.md"
  local t
  for t in comparison.html decision.html intake.html plan.html; do
    cp "$(fetch "claude/skills/render/templates/$t")" "$CLAUDE_DIR/skills/render/templates/$t"
  done
  ok "render skill installed"
}
install_sound() {
  ensure_settings
  append_hook Notification "afplay /System/Library/Sounds/Submarine.aiff"
  append_hook Stop         "afplay /System/Library/Sounds/Glass.aiff"
  ok "sound cues installed (Submarine = needs you, Glass = done)"
  info "swap the .aiff names to taste; see /System/Library/Sounds"
}
install_flint() {
  ensure_settings
  jq_set '
    .extraKnownMarketplaces.flint = {source:{source:"github", repo:"jah2488/flint"}}
    | .enabledPlugins["flint@flint"] = true
  '
  ok "flint enabled (marketplace github:jah2488/flint)"
  info "Claude Code installs it on next start; manage any time with /plugin"
}

choose_terminal() { # echoes one of: alacritty ghostty iterm2
  local opts=() i
  [ "$term_alacritty" = 1 ] && opts+=(alacritty)
  [ "$term_ghostty" = 1 ]   && opts+=(ghostty)
  [ "$term_iterm" = 1 ]     && opts+=(iterm2)
  if [ "${#opts[@]}" -eq 1 ]; then printf '%s' "${opts[0]}"; return; fi
  if [ "$INTERACTIVE" != 1 ]; then printf '%s' "${opts[0]}"; return; fi
  printf '\n%swhich terminal?%s\n' "$B" "$R" > /dev/tty
  for i in $(seq 0 $((${#opts[@]}-1))); do printf '  %d. %s\n' "$((i+1))" "${opts[$i]}" > /dev/tty; done
  local reply; reply="$(ask "pick a number: ")"
  case "$reply" in
    ''|*[!0-9]* ) printf '%s' "${opts[0]}" ;;
    * ) if [ "$reply" -ge 1 ] && [ "$reply" -le "${#opts[@]}" ]; then printf '%s' "${opts[$((reply-1))]}"; else printf '%s' "${opts[0]}"; fi ;;
  esac
}
install_theme() {
  local which; which="$(choose_terminal)"
  case "$which" in
    alacritty)
      if [ "$IS_MAC" = 1 ]; then
        bash "$(fetch terminal/alacritty/apply-low-load-theme.sh)"
        ok "Alacritty theme applied (font + colors + leading)"
      else
        mkdir -p "$HOME/.config/alacritty/themes"
        cp "$(fetch terminal/alacritty/low-load.toml)" "$HOME/.config/alacritty/themes/low-load.toml"
        ok "Alacritty theme written to ~/.config/alacritty/themes/low-load.toml"
        info "add it to alacritty.toml: [general] import = [\"~/.config/alacritty/themes/low-load.toml\"]"
        info "and install JetBrains Mono: https://www.jetbrains.com/lp/mono/"
      fi ;;
    ghostty)
      local gdir="$HOME/.config/ghostty"
      mkdir -p "$gdir"
      cp "$(fetch terminal/ghostty/low-load.conf)" "$gdir/low-load.conf"
      touch "$gdir/config"
      if grep -qF "low-load.conf" "$gdir/config" 2>/dev/null; then
        info "Ghostty config already imports low-load.conf"
      else
        printf 'config-file = %s/low-load.conf\n' "$gdir" >> "$gdir/config"
      fi
      ok "Ghostty theme wired into ~/.config/ghostty/config"
      info "install JetBrains Mono if missing: https://www.jetbrains.com/lp/mono/"
      info "reload Ghostty (Cmd+Shift+, ) or open a new window" ;;
    iterm2)
      local f; f="$(fetch terminal/iterm2/LowLoad.itermcolors)"
      cp "$f" "$HOME/LowLoad.itermcolors"
      [ "$IS_MAC" = 1 ] && open "$HOME/LowLoad.itermcolors" 2>/dev/null || true
      ok "iTerm2 color preset 'LowLoad' imported (saved to ~/LowLoad.itermcolors)"
      info "select it: Settings > Profiles > Colors > Color Presets > LowLoad"
      info "then set font JetBrains Mono 14, steady box cursor, 18/16 margins (see iterm2/README.md)" ;;
  esac
}

# ---------- run --------------------------------------------------------------
banner
[ "$HAS_CURL" = 1 ] || { bad "curl is required"; exit 1; }
print_capabilities
select_components

head2 "Installing"
ANY=0
is_sel style      && { install_style;      ANY=1; }
is_sel statusline && { install_statusline; ANY=1; }
is_sel render     && { install_render;     ANY=1; }
is_sel sound      && { install_sound;      ANY=1; }
is_sel theme      && { install_theme;      ANY=1; }
is_sel flint      && { install_flint;      ANY=1; }

rule
if [ "$ANY" = 1 ]; then
  head2 "Done"
  [ "$SETTINGS_BACKED_UP" = 1 ] && info "settings.json backed up next to itself before editing"
  info "restart Claude Code (or run /clear) to load the output style and status line"
  printf '%sless to read. enjoy the quiet.%s\n' "$D" "$R"
else
  warn "nothing selected — re-run any time"
fi
