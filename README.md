# AI-hot-keys

Turn rough, typo-ridden text into a clean, well-written version — in place,
in any app, with one keyboard shortcut. No copy-pasting into a chat window,
no switching apps.

## What this does

Select some text anywhere on your Mac — an email draft, a Slack message, a
note, a document — press **⌘⌥R**, and the selected text is replaced with an
AI-rephrased version. Bold/bullet formatting is preserved as plain
Unicode-styled text, so it always matches whatever font your document is
already using, instead of pasting in with the wrong font.

It runs quietly in the background (via [Hammerspoon](https://www.hammerspoon.org/))
and works the same way in Gmail, Outlook, Word, Notes, Notion, and pretty
much anywhere else you can select text — not just one specific app.

Rephrasing is done by Google's Gemini API using your own API key, so usage
is billed to your own account (typically pennies a month for personal use).

## Install

Open Terminal and run:

```
curl -fsSL https://raw.githubusercontent.com/tathagatankit/AI-hot-keys/main/install.sh | bash
```

This requires [Homebrew](https://brew.sh) to already be installed. The
script will:

1. Install Hammerspoon (if you don't already have it)
2. Set everything up automatically
3. Ask you to paste in a Gemini API key — get one free at
   [aistudio.google.com/apikey](https://aistudio.google.com/apikey) (it's
   stored securely in macOS Keychain, never written to a file)
4. Open System Settings to the one screen where **you'll need to manually
   turn on a toggle** — macOS requires a real person to approve this kind of
   permission, so no script (this one included) can do it for you:

   **System Settings → Privacy & Security → Accessibility → turn on Hammerspoon**

That's it — once the toggle is on, select some text anywhere and try **⌘⌥R**.

Re-running the same command later safely updates you to the latest version
without touching your existing settings or API key.

### Alternate installation methods

**Don't want to pipe a script straight into `bash`?** That's a reasonable
instinct. Clone the repo first so you can read `install.sh` before running
it:

```
git clone https://github.com/tathagatankit/AI-hot-keys.git
cd AI-hot-keys
./install.sh
```

**Prefer to do it entirely by hand?** Every step the script automates:

1. Install Hammerspoon: `brew install --cask hammerspoon`
2. Clone this repo somewhere permanent, e.g. `git clone https://github.com/tathagatankit/AI-hot-keys.git ~/AI-hot-keys`
3. Symlink it into Hammerspoon's config folder:
   `ln -s ~/AI-hot-keys/hammerspoon/rephrase ~/.hammerspoon/rephrase`
4. Add `require("rephrase.init")` to `~/.hammerspoon/init.lua` (create the
   file if it doesn't exist)
5. Copy the example config: `cp ~/AI-hot-keys/hammerspoon/rephrase/config.lua.example ~/AI-hot-keys/hammerspoon/rephrase/config.lua`
6. Get a Gemini API key from [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
7. Store it in Keychain: `security add-generic-password -a "$USER" -s "rightclick-rephrase" -w "YOUR_KEY_HERE"`
8. Launch Hammerspoon, then grant it Accessibility permission in System
   Settings → Privacy & Security → Accessibility

## Using it

Select text, press **⌘⌥R**, wait a second — the text is replaced in place.

**In Gmail**, drafting a quick reply:

> hey can u send me the numbers for q3 asap thx

becomes:

> Could you please send me the Q3 numbers as soon as possible?

**In Notes or Word**, cleaning up a hasty note:

> need to reschedule the standup meeting for tmrw bc half the team is out sick, maybe friday instead

becomes:

> We need to reschedule tomorrow's standup meeting because half the team is
> out sick. Can we move it to **Friday** instead?

Key points that matter always, everywhere:
> **Q3 numbers**, **Friday** — get styled so they stand out, without ever
changing your document's font or size.

If nothing happens, double check Hammerspoon has Accessibility permission
(see the Install section above) and that a text selection actually existed
when you pressed the hotkey.

## Configuration

After install, your personal settings live at
`~/AI-hot-keys/hammerspoon/rephrase/config.lua`. You can change:

- `hotkey` — the keyboard shortcut (default `⌘⌥R`)
- `model` — which Gemini model to use
- `format_mode` — `"unicode"` (default, always matches your document's font)
  or `"rtf"` (real bold/bullet formatting, but may override your current
  font on paste)

After editing, reload Hammerspoon (menu bar icon → Reload Config) for
changes to take effect.

## Uninstall

```
~/AI-hot-keys/uninstall.sh
```

Asks for confirmation before deleting your stored API key or the cloned
repo — safe to run any time.

---

For architecture details, see `docs/superpowers/specs/2026-07-01-system-wide-text-rephrase-design.md`.
