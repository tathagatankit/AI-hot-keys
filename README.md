# rightClick — System-Wide Text Rephrase

Select text in any macOS app, press a hotkey, and have it replaced in place
with an LLM-rephrased version. See `docs/superpowers/specs/2026-07-01-system-wide-text-rephrase-design.md`
for the full design.

## One-time setup

1. Install Hammerspoon: `brew install --cask hammerspoon`, then launch it once
   and grant it Accessibility permission when macOS prompts (System Settings ->
   Privacy & Security -> Accessibility).
2. Install Lua for running this repo's tests standalone: `brew install lua`.
3. Symlink this repo's Hammerspoon module into your Hammerspoon config dir:
   `ln -s "$(pwd)/hammerspoon/rephrase" ~/.hammerspoon/rephrase`
4. Add `require("rephrase.init")` to `~/.hammerspoon/init.lua` (create the file
   if it doesn't exist).
5. Copy the example config: `cp hammerspoon/rephrase/config.lua.example hammerspoon/rephrase/config.lua`
   and adjust the hotkey/model if you want.
6. Get a Gemini API key from https://aistudio.google.com/apikey (separate from
   any ChatGPT/Gemini consumer subscription — this is a pay-as-you-go API key).
7. Store the key in Keychain (never in a file):
   `security add-generic-password -a "$USER" -s "rightclick-rephrase" -w "YOUR_KEY_HERE"`
8. In Hammerspoon's menu bar icon, choose "Reload Config".
9. Select some text anywhere, press `⌘⌥R`, confirm it gets rephrased in place.

## Running tests

`./hammerspoon/rephrase/test/run_tests.sh`

## Manual verification

- [ ] TextEdit/Notes: select a plain paragraph, press ⌘⌥R, confirm replaced text is sensible and any bold/bullets render correctly.
- [ ] CotEditor (plain-text editor): select text, press ⌘⌥R, confirm the replacement is clean plain text (no visible HTML tags or RTF control words).
- [ ] Microsoft Word: select a paragraph, press ⌘⌥R, confirm bullets/bold render as real Word formatting, not literal asterisks or tags.
- [ ] Notion desktop: select text in a page, press ⌘⌥R, confirm replacement lands with formatting.
- [ ] Outlook desktop: select text in a draft email, press ⌘⌥R, confirm replacement lands correctly.
- [ ] Gmail in Chrome: select text in a compose window, press ⌘⌥R, confirm replacement lands correctly (this is the hotkey path working in a browser, not the Phase 2 Chrome extension).
- [ ] Select nothing (click without selecting), press ⌘⌥R, confirm a "nothing selected" HUD appears and the real clipboard is untouched.
- [ ] Copy something to the clipboard, select text elsewhere, press ⌘⌥R, wait for the paste to complete, then paste (⌘V) again a few seconds later — confirm the original clipboard content comes back (clipboard restore works).
- [ ] Temporarily rename the Keychain entry (`security rename` isn't a real flag — instead delete it: `security delete-generic-password -a "$USER" -s "rightclick-rephrase"`), press ⌘⌥R on a selection, confirm an error HUD appears instead of a silent failure or garbage paste. Re-add the key afterward.
