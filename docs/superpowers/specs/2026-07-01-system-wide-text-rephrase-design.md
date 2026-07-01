# System-Wide Text Rephrase Tool — Design

## Problem

Rephrasing text (emails, notes, docs) currently means copying it out to an LLM chat, pasting the result back manually, and losing formatting (bullets, emphasis) in the process. This tool should let the user select text in *any* macOS app, trigger a rephrase, and have the result — with sensible formatting — replace the selection in place, automatically.

## Goals

- Select text anywhere (Word, Outlook desktop, Notion desktop, Notes, CotEditor, Gmail in browser) and rephrase it via a global hotkey.
- Result auto-replaces the selection instantly — no confirmation step.
- Output preserves/adds structure where it helps (bold key points, bullet lists) rather than always being flat prose, and degrades gracefully to plain text in plain-text-only editors.
- LLM backend starts on Gemini, but is swappable to OpenAI/Anthropic without touching the core flow.
- Runs continuously in the background on the user's Mac.

## Non-Goals (for now)

- No native macOS Services-menu ("right-click → Services") entry. This would require a separately compiled helper app (Hammerspoon can't register `NSServices` from Lua) purely to duplicate what the hotkey already does in native apps. Not worth the build cost — revisit only if the hotkey proves inconvenient in some specific app.
- No confirm/preview popup before replacing text — auto-replace was chosen deliberately for speed; safety net is clipboard restore + a visible error HUD on failure.
- No mode picker (formal email / concise notes / etc.) — a single smart mode infers what's needed from the text itself.
- ChatGPT Go's consumer subscription cannot be used — it has no API access, and reverse-engineering the ChatGPT web session to fake API access would violate OpenAI's Terms of Service. Any provider used here must be a real, separately-billed API key.

## Architecture

Two components, sharing one backend:

1. **Hammerspoon config** (Lua) — the core engine. Runs continuously, listens for a global hotkey, does the rephrase, pastes the result back. Works identically in every app (native Cocoa, Electron, and browser tabs) because it operates via simulated keystrokes and the system clipboard, not app-specific integration.
2. **Chrome extension** (Phase 2) — adds a genuine right-click "Rephrase" context-menu entry for selected text on web pages (Gmail, Notion web, etc.), calling into a local HTTP endpoint hosted by the same Hammerspoon script. One shared backend, one place secrets live.

Provider logic is abstracted into small per-provider Lua modules so swapping Gemini → OpenAI/Anthropic later means adding one ~30-line module, not touching the flow.

## Phasing

- **Phase 1 (MVP)**: Hammerspoon hotkey + Gemini provider + Keychain-stored key + clipboard rich-paste. Fully functional across every named app, including Gmail (via hotkey, not right-click).
- **Phase 2**: Local HTTP server (`hs.httpserver`, bound to `127.0.0.1`) + Chrome extension, adding genuine right-click specifically on the web.

Phase 1 ships and gets used before Phase 2 is built.

## Phase 1: Rephrase Flow

1. User selects text anywhere, presses the global hotkey (default `⌘⌥R`, configurable).
2. Script saves current clipboard contents (to restore later).
3. Simulates `⌘C`, reads the clipboard as plain text.
   - If the clipboard is empty/unchanged after the simulated copy (i.e. nothing was selected), show a "Nothing selected" HUD and stop.
4. Shows a "Rephrasing…" HUD (`hs.alert`) — the LLM call takes a second or two and there's no other confirmation step, so the user should see it's in flight.
5. Input length is capped (~8000 characters); longer selections trigger a "Selection too long" HUD instead of sending an oversized request.
6. Sends the text to the active provider module with an instruction to rephrase clearly and mark up structure with a small safe HTML subset (`<b>`, `<ul>/<li>`, `<p>`) only where it genuinely helps — not forced on every response.
7. Provider module returns HTML (or an error).
   - On error (network failure, bad key, rate limit): restore clipboard immediately, show an error HUD with the failure reason, do not paste.
8. Wrap the returned HTML in a minimal `<html><body>...</body></html>` shell and convert to RTF via macOS's built-in `textutil -convert rtf -stdin -stdout -format html`.
   - If `textutil` conversion fails, fall back to pasting the raw HTML response as plain text (tags stripped) rather than aborting.
9. Write both RTF and a plain-text fallback (tags stripped) to the clipboard, so rich apps (Word, Notes, Notion) render formatting and plain editors (CotEditor) get clean plain text.
10. Simulate `⌘V` to paste, replacing the original selection in place.
11. After a short delay (long enough for the paste to land), restore the original clipboard contents so the user's normal copy/paste history isn't clobbered.

## Config & Secrets

- **API key**: stored in macOS Keychain, added once via the `security` CLI (e.g. `security add-generic-password -a "$USER" -s "rightclick-rephrase" -w "<key>"`), read at runtime via `hs.execute("security find-generic-password ... -w")`. Never stored in a plaintext file.
- **Config file** (`~/.hammerspoon/rephrase/config.lua`, gitignored): hotkey binding, active provider name (`"gemini"` initially), model name (e.g. `gemini-2.5-flash`). No secrets here.
- **Provider abstraction**: one Lua module per provider (`providers/gemini.lua`, later `providers/openai.lua`, `providers/anthropic.lua`), each exposing `rephrase(text) -> html_or_error`. Selected by the `provider` config value; the core flow only ever calls the currently active module.

## Phase 2: Chrome Extension (deferred)

- Manifest V3 extension adding a "Rephrase" context-menu item for `contexts: ['selection']`.
- On click, sends the selected text to `http://127.0.0.1:<port>/rephrase`, hosted by the same Hammerspoon script (`hs.httpserver`), bound to loopback only.
- A locally-generated shared-secret header between the extension and the local server, as defense-in-depth against other local processes/pages probing the port.
- Result HTML is inserted directly into the page's editable region via the Selection/Range API (no RTF conversion needed — that's only for the native clipboard-paste path).

## Testing / Verification

This is a personal automation tool, not a library — verification is manual, but the core pieces should be separable enough to sanity-check independently:

- Provider module: callable in isolation with a sample string, inspect the returned HTML.
- HTML→RTF conversion: testable directly via `textutil` on a fixed sample HTML string.
- End-to-end manual checklist across the named apps (Word, Outlook desktop, Notion desktop, Notes, CotEditor, Gmail in Chrome): select text, hit hotkey, confirm replacement and formatting land correctly; confirm clipboard is restored after; confirm error HUD appears when the API key is temporarily invalidated.
