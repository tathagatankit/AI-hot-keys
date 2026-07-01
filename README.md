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
