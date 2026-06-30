---
name: render
description: >-
  Render dense, read-heavy content (plans, option comparisons, decisions, intake
  forms) as a styled local HTML page and open it in the browser, instead of dumping
  it as a wall of text in the terminal. Use when output is genuinely table-heavy,
  a multi-step plan, a comparison of 3+ options, a decision writeup, or when you
  need structured input from the user via a form. Invoke on request (/render) or
  proactively when terminal prose would be hard to scan.
---

# render — move dense content out of the terminal

The terminal is the wrong surface for long plans, big comparison tables, or forms —
full-width prose on a large screen is fatiguing to scan. This skill renders that content
as a clean, scannable webpage and opens it, keeping the terminal for the terse answer.

Apply the low-load design principles: ~65ch measure, high data-ink (no chartjunk),
one preattentive cue (highlight the recommended/changed thing), and `<details>` for
progressive disclosure so depth is pulled, not pushed.

## When to use
- **plan** — a multi-step plan or checklist with collapsible detail per step.
- **comparison** — 3+ options across criteria; recommend one (highlighted row).
- **decision** — a TL;DR recommendation with rationale/tradeoffs collapsed below.
- **intake** — you need structured input; user fills a form and copies JSON back.

Skip it for short answers — terminal is fine for those. Don't render what fits in 3 lines.

## Protocol
1. **Pick a template** in `templates/` matching the content type.
2. **Read it**, then author a filled copy: replace the `<!-- FILL -->` regions with the
   real content. Keep the `<style>` block as-is (each output is standalone).
3. **Write** the result to `${TMPDIR:-/tmp}/claude-render/<slug>.html` (create the dir).
4. **Open it**: `open "<path>"` (macOS) or `xdg-open "<path>"` (Linux). Output the path too, so it's clickable.
5. In the terminal, give only the **one-line takeaway** (e.g. recommendation), not the
   full content — the page holds the detail. Then stop.

## Forms (intake) round-trip
There is no server. The `intake.html` form has a **Copy results** button that serializes
fields to JSON and copies to the clipboard (with a visible textarea fallback). The user
fills it, clicks copy, and pastes the JSON back into the chat. Read that JSON and continue.

## Notes
- Templates are standalone HTML with inline CSS — the output file works with no assets.
- Don't add libraries or external fonts; system font only, light/dark aware.
- Keep one accent color as the single preattentive cue; don't decorate.
