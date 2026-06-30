# Low Load

Claude Code, tuned for tired eyes.

If you spend hours a day across several AI chats, the cost is not the thinking. It is
the reading. Every answer arrives as a wall of friendly prose at full terminal width,
and you scan all of it to find the one line that matters. Do that a few hundred times a
day and you are worn out by an interface, not the work. If you are dyslexic or have ADHD,
the tax is higher: dense paragraphs, low contrast, and a blinking cursor all pull
attention you would rather spend elsewhere.

Low Load is a small bundle of changes that make Claude Code calmer to use. Answers lead
with the conclusion and stay short. State lives in a glanceable status bar instead of
prose. Long plans and tables move out of the terminal onto a clean page. And the terminal
itself gets a typography pass built for fatigue and dyslexia.

None of it is magic. It is a few config files and one output style, packaged so you can
pick the parts you want and skip the rest.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jah2488/low-load/main/install.sh | bash
```

The installer checks what your system supports, then lets you toggle each piece on or off
before it touches anything. It backs up your `settings.json` first and never overwrites
hooks you already have. Piping a script into a shell deserves a look first:
[read it here](https://github.com/jah2488/low-load/blob/main/install.sh).

Prefer to clone? `git clone https://github.com/jah2488/low-load && cd low-load && ./install.sh`.

## What's in it

| Piece | What it does | Needs |
|---|---|---|
| **Output style** | Answer-first, terse, scannable replies. This is most of the benefit. | jq |
| **Status line** | One glanceable bar: model, context %, rate limit, branch. No cost shown, on purpose. | jq |
| **render skill** | Moves long plans, comparison tables, and forms out of the terminal onto a clean local web page. | none |
| **Sound cues** | A soft chime when Claude needs you, another when it finishes. Monitor several sessions by ear. | macOS |
| **Terminal theme** | Dyslexia-friendly typography for Alacritty, Ghostty, or iTerm2. | a supported terminal |
| **flint** *(optional)* | A companion plugin that makes Claude build less and claim less, not just say less. | jq |

Take the output style alone and you have most of the win. The rest is gravy.

## The output style, before and after

A status check, the default way:

> Great question! I went ahead and checked the test suite for you. The good news is that
> almost everything is passing. There is just one test that is currently failing, which is
> the billing webhook retry test. It looks like it might be related to a timeout. Let me
> know if you would like me to dig into it further!

The same answer, on Low Load:

> ✗ 1 failing: `billing webhook retry` (timeout)
> 41 others green.
> -> more (stack trace / likely cause)

Same information. A tenth of the reading. Depth is one line away when you want it.

## The terminal theme

Typography choices that lower reading load, drawn from dyslexia and low-vision research:

- **JetBrains Mono** at a comfortable size, with generous line spacing so lines stop blending.
- **Gentle contrast.** Off-black background, warm off-white text. No pure black on pure white,
  which halates and strains tired eyes, while still keeping high (~12:1) contrast.
- **A steady block cursor.** Easy to find, no blink to chase.
- **Breathing-room padding**, so it is easier to find your place after an interruption.

Themes ship for Alacritty, Ghostty, and iTerm2. The installer wires in whichever you use.

## flint

Low Load makes Claude *say* less. [flint](https://github.com/jah2488/flint) makes it *do*
less: build only what is needed, and claim only what it can prove. They pair naturally, so
the installer offers to enable flint for you. It is entirely optional and easy to remove
with `/plugin`.

## Safety and privacy

- **Local only.** Everything runs on your machine. No network calls, no telemetry.
- **Non-destructive.** Your `settings.json` is backed up before any edit, and existing
  hooks are appended to, never replaced. Terminal configs are backed up too.
- **Re-runnable.** Run the installer again any time to add or change pieces.
- **MIT licensed.** Read it, fork it, make it yours.

## Manual install

Not into the one-liner? Each piece is a plain file:

- Copy `claude/output-styles/low-load.md` to `~/.claude/output-styles/`, then set
  `"outputStyle": "Low Load"` in `~/.claude/settings.json`.
- Copy `claude/statusline.sh` to `~/.claude/`, `chmod +x` it, and point
  `"statusLine"` at it (see `claude/settings.snippet.json`).
- Copy `claude/skills/render/` to `~/.claude/skills/`.
- For sound cues and flint, merge the relevant keys from `claude/settings.snippet.json`.
- For the terminal theme, see the files under `terminal/`.

## More for Claude Code

- [**shutdown**](https://safe-to-shutdown.netlify.app): graceful end-of-session cleanup.
  Saves what dies with the context, makes git safe, then says "safe to shutdown".
- [**flint**](https://github.com/jah2488/flint): one mode that makes Claude build less,
  say less, and claim less.
- [**why**](https://github.com/jah2488/why): code archaeology. Recover the full history
  and intent behind a piece of code.
- [**tend**](https://github.com/jah2488/tend): keep every Claude Code session in view.
- [**eng-audit**](https://github.com/jah2488/eng-audit) and
  [**ultravalidate**](https://github.com/jah2488/ultravalidate): audit changes against your
  engineering principles, and refute a result before you trust it.

## License

MIT. Built by [@jah2488](https://github.com/jah2488).
