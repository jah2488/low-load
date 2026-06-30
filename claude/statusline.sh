#!/bin/bash
# Low-load status line: [name] model · flint · eff · style · ctx% ⚠ · 5h% · +/- · branch
# State out of prose, into a glanceable bar. Preattentive cue: color on the %s + the ⚠.
input=$(cat)

NAME=$(echo "$input" | jq -r '.session_name // empty')
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
RL=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
SID=$(echo "$input" | jq -r '.session_id // empty')
STYLE=$(echo "$input" | jq -r '.output_style.name // empty')
EFF=$(echo "$input" | jq -r '.effort.level // empty')
LADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LDEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

DIM=$'\033[2m'; RST=$'\033[0m'; BLD=$'\033[1m'
GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'
SEP="${DIM} · ${RST}"

# color thresholds: green / amber / red
color(){ if [ "$1" -ge "$3" ]; then printf '%s' "$RED"; elif [ "$1" -ge "$2" ]; then printf '%s' "$YEL"; else printf '%s' "$GRN"; fi; }

# Session name (only when set via --name / /rename) — first, as the chat's identity
PREFIX=""
[ -n "$NAME" ] && PREFIX="${BLD}${NAME}${RST}${SEP}"

# flint segment (only when the plugin is installed). Level comes from the per-session
# statefile that flint-mode.sh writes; absent file => full, since flint is on-by-default
# each session (its SessionStart hook). Glyph color = intensity, matching the bar's
# "color carries the signal" rule: feral red, ultra amber, full/lite green, off dim.
FLINT=""
if compgen -G "$HOME/.claude/plugins/cache/flint/flint/*/skills/flint" >/dev/null 2>&1; then
  MODE=full
  SF="${TMPDIR:-/tmp}/claude-flint-mode-${SID}"
  [ -n "$SID" ] && [ -r "$SF" ] && MODE=$(cat "$SF" 2>/dev/null)
  case "$MODE" in
    off)   FLINT="${SEP}${DIM}✦ flint off${RST}" ;;
    feral) FLINT="${SEP}${RED}✦${RST} ${DIM}flint:${RST}feral" ;;
    ultra) FLINT="${SEP}${YEL}✦${RST} ${DIM}flint:${RST}ultra" ;;
    *)     FLINT="${SEP}${GRN}✦${RST} ${DIM}flint:${RST}${MODE}" ;;
  esac
fi

# Reasoning effort (set live via /effort) — absent when the model lacks the param.
# Dimmed label, plain level: ambient like style, not a warning.
EFFSEG=""
[ -n "$EFF" ] && EFFSEG="${SEP}${DIM}eff:${RST}${EFF}"

# Output style (e.g. "Low Load") — ambient, dimmed; confirms which mode is live
STYLESEG=""
[ -n "$STYLE" ] && STYLESEG="${SEP}${DIM}${STYLE}${RST}"

# Context % — color ramps green→amber→red; a ⚠ flips on near auto-compact.
# Keyed on used_percentage (window-agnostic), NOT exceeds_200k_tokens: on a 1M
# window 200k is only 20%, so that flag would warn far too early.
if [ -n "$PCT" ]; then
  CTX="$(color "$PCT" 50 80)ctx ${PCT}%${RST}"
  [ "$PCT" -ge 90 ] 2>/dev/null && CTX="${CTX}${RED}⚠${RST}"
else
  CTX="${DIM}ctx -${RST}"
fi

# 5-hour rate limit % (only present for Pro/Max after first API response) — see the wall coming
RLSEG=""
[ -n "$RL" ] && RLSEG="${SEP}$(color "$RL" 60 85)5h ${RL}%${RST}"

# Lines changed this session (+added/-removed) — work-progress signal, hidden at zero
LINES=""
if [ "$LADD" -gt 0 ] 2>/dev/null || [ "$LDEL" -gt 0 ] 2>/dev/null; then
  LINES="${SEP}${GRN}+${LADD}${RST}${DIM}/${RST}${RED}-${LDEL}${RST}"
fi

# Git branch + dirty marker (no native field; compute from cwd)
GIT=""
if [ -n "$DIR" ] && git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BR=$(git -C "$DIR" branch --show-current 2>/dev/null)
  [ -z "$BR" ] && BR=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ]; then MARK="${YEL}*${RST}"; else MARK="${GRN}✓${RST}"; fi
  GIT="${SEP}${BR} ${MARK}"
fi

printf '%s%s%s%s%s%s%s%s' "$PREFIX" "$MODEL" "$FLINT" "$EFFSEG" "$STYLESEG" "$SEP" "$CTX" "$RLSEG$LINES$GIT"
