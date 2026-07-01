# System-Wide Text Rephrase Tool (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Phase 1 MVP from the design spec — a Hammerspoon-based background tool that lets the user select text in any macOS app, press a global hotkey, and have the selection auto-replaced with an LLM-rephrased version (via Gemini), with formatting (bold, bullets) preserved where it helps.

**Architecture:** Pure Hammerspoon Lua config (no compiled app). A hotkey handler grabs the selection via simulated `⌘C`/clipboard read, calls a swappable LLM provider module (Gemini first), converts the HTML result to RTF via macOS's built-in `textutil`, writes both RTF and plain-text to the clipboard, and pastes it back via simulated `⌘V`. The API key lives in macOS Keychain, never in a file. Provider logic, HTML→RTF conversion, and Keychain access are all built as small, dependency-injected pure-ish modules so they're unit-testable with a plain `lua` interpreter, independent of the running Hammerspoon app; only the final hotkey-orchestration glue (`init.lua`) is verified manually.

**Tech Stack:** Hammerspoon (Lua 5.4 runtime, `hs.*` APIs), macOS `textutil` and `security` CLIs, Google Gemini `generateContent` REST API, Homebrew `lua` (5.5, dev-only) for standalone test runs.

## Global Constraints

- macOS only; requires Hammerspoon installed and running with Accessibility permission granted.
- No API keys or other secrets in any file committed to git or living in `~/.hammerspoon/*.lua` as plaintext — the key lives only in macOS Keychain, under service name `rightclick-rephrase`.
- Input selections longer than 8000 characters are rejected with a HUD message rather than sent to the API (from spec's Phase 1 flow, step 5).
- Default hotkey is `⌘⌥R` (`cmd+alt+R`), configurable in `hammerspoon/rephrase/config.lua` (gitignored; `config.lua.example` is the tracked template).
- Default Gemini model is `gemini-3.5-flash`, configurable in the same config file.
- All HTTP calls to the LLM provider must be asynchronous (`hs.http.asyncPost`), not the blocking `hs.http.post` — confirmed via Hammerspoon docs that `post` blocks the entire Hammerspoon main thread (freezing all hotkeys/UI) for the duration of the network call, which is unacceptable given the "Rephrasing…" HUD needs to render before the multi-second call completes.
- Verified real external API shapes (do not deviate without re-checking docs):
  - Gemini endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}`
  - Gemini request body: `{"contents": [{"parts": [{"text": "..."}]}], "system_instruction": {"parts": [{"text": "..."}]}}`
  - Gemini response body: `{"candidates": [{"content": {"parts": [{"text": "..."}]}}]}`
  - `hs.pasteboard.readAllData([name]) -> table` (UTI → raw data)
  - `hs.pasteboard.writeAllData([name], table) -> boolean`
  - `hs.pasteboard.readString([name], [all]) -> string`
  - `hs.eventtap.keyStroke(modifiers, character[, delay, application])`
  - `hs.http.asyncPost(url, data, headers, callback)` where `callback(status, body, headers)`
  - `hs.hotkey.bind(mods, key, pressedfn)`
  - `hs.timer.doAfter(sec, fn) -> timer`
  - `hs.alert.show(str, ...) -> uuid`

---

## File Structure

```
rightClick/
  hammerspoon/
    rephrase/
      init.lua                  # hotkey binding + orchestration (glue, manually tested)
      config.lua.example        # tracked template; copy to config.lua (gitignored)
      shellquote.lua             # POSIX shell-quoting helper (used by html_to_rtf, keychain)
      html_to_rtf.lua            # HTML -> RTF via textutil; HTML -> plain text stripping
      keychain.lua                # macOS Keychain read via `security` CLI
      providers/
        init.lua                # provider registry/dispatch by name
        gemini.lua               # Gemini REST call (request build, response parse, async call)
      clipboard.lua               # pasteboard save/restore/read/write, DI'd on hs.pasteboard
      test/
        testkit.lua              # tiny hand-rolled assertion/reporting helper
        shellquote_test.lua
        html_to_rtf_test.lua
        keychain_test.lua
        gemini_test.lua
        providers_test.lua
        clipboard_test.lua
      run_tests.sh               # runs all *_test.lua files with plain `lua`
  .gitignore
  README.md
```

**Interfaces at a glance** (exact names/signatures every task must match):

- `shellquote.quote(s) -> string`
- `html_to_rtf.wrap_html(html_fragment) -> string`
- `html_to_rtf.strip_tags(html_fragment) -> string`
- `html_to_rtf.convert_to_rtf(html_fragment, [shell_fn]) -> rtf_string_or_nil, err_or_nil`
- `keychain.get_key([account], [shell_fn]) -> key_string_or_nil, err_or_nil`
- `providers.gemini.build_request_body(text) -> table`
- `providers.gemini.parse_response_body(decoded_table) -> html_string_or_nil, err_or_nil`
- `providers.gemini.rephrase(text, opts, callback)` where `callback(html_string_or_nil, err_or_nil)`, `opts = {api_key=, model=, http_post=, json_encode=, json_decode=}`
- `providers.get(name) -> provider_module_or_nil, err_or_nil`
- `clipboard.save([pb]) -> table`
- `clipboard.restore(saved, [pb]) -> boolean`
- `clipboard.read_plain([pb]) -> string_or_nil`
- `clipboard.write_rich(rtf_bytes, plain_text, [pb]) -> boolean`
- `clipboard.write_plain(plain_text, [pb]) -> boolean`

---

### Task 1: Project scaffolding

**Files:**
- Create: `.gitignore`
- Create: `hammerspoon/rephrase/config.lua.example`
- Create: `README.md`

**Interfaces:**
- Produces: the `config.lua.example` shape (`provider`, `model`, `hotkey.mods`, `hotkey.key`, `max_input_chars`) that Task 8's `init.lua` reads.

- [ ] **Step 1: Create `.gitignore`**

```
hammerspoon/rephrase/config.lua
```

- [ ] **Step 2: Create the example config**

`hammerspoon/rephrase/config.lua.example`:

```lua
return {
  provider = "gemini",
  model = "gemini-3.5-flash",
  hotkey = { mods = { "cmd", "alt" }, key = "R" },
  max_input_chars = 8000,
}
```

- [ ] **Step 3: Verify the example config loads with plain Lua**

Run: `lua -e "local c = dofile('hammerspoon/rephrase/config.lua.example'); assert(c.provider == 'gemini'); assert(c.hotkey.key == 'R'); print('OK')"`

Expected: `OK` printed, no errors. If `lua: command not found`, run `brew install lua` first (Homebrew's `lua` formula installs both `lua` and version-suffixed symlinks — the plain `lua` command works regardless of version).

- [ ] **Step 4: Verify required macOS system tools are present**

Run: `command -v textutil && command -v security && echo OK`

Expected: prints two paths (e.g. `/usr/bin/textutil`, `/usr/bin/security`) then `OK`. Both ship with macOS; if either is missing, something is unusually wrong with the system and later tasks will fail.

- [ ] **Step 5: Write the README with setup instructions**

`README.md`:

```markdown
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
```

- [ ] **Step 6: Commit**

```bash
git add .gitignore hammerspoon/rephrase/config.lua.example README.md
git commit -m "Add project scaffolding, example config, and setup README"
```

---

### Task 2: `shellquote` module

**Files:**
- Create: `hammerspoon/rephrase/shellquote.lua`
- Create: `hammerspoon/rephrase/test/testkit.lua`
- Test: `hammerspoon/rephrase/test/shellquote_test.lua`

**Interfaces:**
- Produces: `shellquote.quote(s) -> string` — used by Task 3 (`html_to_rtf`) and Task 4 (`keychain`) to safely embed arbitrary strings (file paths, account names) into shell commands.

- [ ] **Step 1: Write the test helper (`testkit.lua`)**

```lua
local M = {}
local pass_count = 0
local fail_count = 0

function M.assert_eq(actual, expected, message)
  if actual == expected then
    pass_count = pass_count + 1
  else
    fail_count = fail_count + 1
    print(string.format("FAIL: %s\n  expected: %s\n  actual:   %s",
      message or "", tostring(expected), tostring(actual)))
  end
end

function M.assert_true(value, message)
  M.assert_eq(value and true or false, true, message)
end

function M.summary()
  print(string.format("\n%d passed, %d failed", pass_count, fail_count))
  if fail_count > 0 then
    os.exit(1)
  end
end

return M
```

- [ ] **Step 2: Write the failing test for `shellquote`**

`hammerspoon/rephrase/test/shellquote_test.lua`:

```lua
package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local shellquote = require("rephrase.shellquote")

testkit.assert_eq(shellquote.quote("hello"), "'hello'", "plain string")
testkit.assert_eq(shellquote.quote("hello world"), "'hello world'", "string with space")
testkit.assert_eq(shellquote.quote("it's"), "'it'\\''s'", "string with single quote")
testkit.assert_eq(shellquote.quote(""), "''", "empty string")

testkit.summary()
```

- [ ] **Step 3: Run test to verify it fails**

Run: `lua hammerspoon/rephrase/test/shellquote_test.lua`
Expected: FAIL with an error like `module 'rephrase.shellquote' not found`, since the module doesn't exist yet.

- [ ] **Step 4: Write the minimal implementation**

`hammerspoon/rephrase/shellquote.lua`:

```lua
local M = {}

function M.quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

return M
```

- [ ] **Step 5: Run test to verify it passes**

Run: `lua hammerspoon/rephrase/test/shellquote_test.lua`
Expected: `4 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add hammerspoon/rephrase/shellquote.lua hammerspoon/rephrase/test/testkit.lua hammerspoon/rephrase/test/shellquote_test.lua
git commit -m "Add shellquote module with tests"
```

---

### Task 3: `html_to_rtf` module

**Files:**
- Create: `hammerspoon/rephrase/html_to_rtf.lua`
- Test: `hammerspoon/rephrase/test/html_to_rtf_test.lua`

**Interfaces:**
- Consumes: none beyond stdlib (`io.popen`, `os.tmpname`, `os.remove`) and `shellquote.quote` from Task 2.
- Produces: `html_to_rtf.wrap_html`, `html_to_rtf.strip_tags`, `html_to_rtf.convert_to_rtf` — used by Task 8's `init.lua`.

- [ ] **Step 1: Write the failing tests**

`hammerspoon/rephrase/test/html_to_rtf_test.lua`:

```lua
package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local html_to_rtf = require("rephrase.html_to_rtf")

-- wrap_html
testkit.assert_eq(
  html_to_rtf.wrap_html("<b>hi</b>"),
  "<html><body><b>hi</b></body></html>",
  "wraps fragment in html/body"
)

-- strip_tags
testkit.assert_eq(
  html_to_rtf.strip_tags("<p>Hello <b>world</b>!</p>"),
  "Hello world!",
  "strips tags, keeps text"
)
testkit.assert_eq(
  html_to_rtf.strip_tags("A&nbsp;B &amp; C"),
  "A B & C",
  "unescapes common entities"
)

-- convert_to_rtf with a fake shell_fn
local seen_cmd = nil
local fake_shell_ok = function(cmd)
  seen_cmd = cmd
  return "{\\rtf1 fake}", true
end
local rtf, err = html_to_rtf.convert_to_rtf("<b>hi</b>", fake_shell_ok)
testkit.assert_eq(rtf, "{\\rtf1 fake}", "returns shell output on success")
testkit.assert_eq(err, nil, "no error on success")
testkit.assert_true(seen_cmd:find("textutil") ~= nil, "command invokes textutil")
testkit.assert_true(seen_cmd:find("-format html") ~= nil, "command specifies html input format")

local fake_shell_fail = function(cmd)
  return "", false
end
local rtf2, err2 = html_to_rtf.convert_to_rtf("<b>hi</b>", fake_shell_fail)
testkit.assert_eq(rtf2, nil, "returns nil on shell failure")
testkit.assert_true(err2 ~= nil, "returns an error message on shell failure")

-- convert_to_rtf with the REAL textutil (integration check, no fake)
local real_rtf, real_err = html_to_rtf.convert_to_rtf("<b>Important</b>")
testkit.assert_eq(real_err, nil, "real textutil conversion has no error")
testkit.assert_true(real_rtf ~= nil and real_rtf:sub(1, 5) == "{\\rtf", "real output is valid RTF")

testkit.summary()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua hammerspoon/rephrase/test/html_to_rtf_test.lua`
Expected: FAIL with `module 'rephrase.html_to_rtf' not found`.

- [ ] **Step 3: Write the minimal implementation**

`hammerspoon/rephrase/html_to_rtf.lua`:

```lua
local shellquote = require("rephrase.shellquote")

local M = {}

function M.wrap_html(html_fragment)
  return "<html><body>" .. html_fragment .. "</body></html>"
end

function M.strip_tags(html_fragment)
  local text = html_fragment:gsub("<[^>]*>", "")
  text = text:gsub("&nbsp;", " ")
  text = text:gsub("&amp;", "&")
  text = text:gsub("&lt;", "<")
  text = text:gsub("&gt;", ">")
  text = text:gsub("&quot;", '"')
  text = text:gsub("&#39;", "'")
  return text
end

local function default_shell(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return nil, false
  end
  local output = handle:read("*a")
  local ok = handle:close()
  return output, ok and true or false
end

function M.convert_to_rtf(html_fragment, shell_fn)
  shell_fn = shell_fn or default_shell
  local wrapped = M.wrap_html(html_fragment)

  local tmp_path = os.tmpname()
  local f = io.open(tmp_path, "w")
  f:write(wrapped)
  f:close()

  local cmd = string.format(
    "textutil -convert rtf -stdin -stdout -format html < %s 2>/dev/null",
    shellquote.quote(tmp_path)
  )
  local output, ok = shell_fn(cmd)
  os.remove(tmp_path)

  if not ok or not output or output == "" then
    return nil, "textutil conversion failed"
  end
  return output
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua hammerspoon/rephrase/test/html_to_rtf_test.lua`
Expected: `9 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add hammerspoon/rephrase/html_to_rtf.lua hammerspoon/rephrase/test/html_to_rtf_test.lua
git commit -m "Add html_to_rtf module with tests"
```

---

### Task 4: `keychain` module

**Files:**
- Create: `hammerspoon/rephrase/keychain.lua`
- Test: `hammerspoon/rephrase/test/keychain_test.lua`

**Interfaces:**
- Consumes: `shellquote.quote` from Task 2.
- Produces: `keychain.get_key([account], [shell_fn]) -> key_string_or_nil, err_or_nil` and `keychain.SERVICE_NAME` — used by Task 8's `init.lua`.

**Note:** the integration test in Step 1 adds and deletes a real (but clearly test-only, distinctly-named) macOS Keychain entry as setup/teardown. It does not touch the production entry (`rightclick-rephrase`) that the README setup instructions create.

- [ ] **Step 1: Write the failing tests**

`hammerspoon/rephrase/test/keychain_test.lua`:

```lua
package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local keychain = require("rephrase.keychain")

-- get_key with a fake shell_fn
local seen_cmd = nil
local fake_shell_ok = function(cmd)
  seen_cmd = cmd
  return "sk-fake-key-123\n", true
end
local key, err = keychain.get_key("testuser", fake_shell_ok)
testkit.assert_eq(key, "sk-fake-key-123", "trims trailing newline")
testkit.assert_eq(err, nil, "no error on success")
testkit.assert_true(seen_cmd:find("security find%-generic%-password") ~= nil, "command invokes security find-generic-password")
testkit.assert_true(seen_cmd:find(keychain.SERVICE_NAME) ~= nil, "command references the service name")

local fake_shell_fail = function(cmd)
  return "", false
end
local key2, err2 = keychain.get_key("testuser", fake_shell_fail)
testkit.assert_eq(key2, nil, "returns nil when not found")
testkit.assert_true(err2 ~= nil, "returns an error message when not found")

-- integration test against a real, distinct test-only Keychain entry
local TEST_SERVICE = "rightclick-rephrase-planitest"
local TEST_ACCOUNT = os.getenv("USER")
os.execute(string.format(
  "security add-generic-password -a %s -s %s -w %s -U 2>/dev/null",
  TEST_ACCOUNT, TEST_SERVICE, "integration-test-value"
))

local function shell_for_test_service(account, shell_fn)
  shell_fn = shell_fn or function(cmd)
    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local ok = handle:close()
    return output, ok and true or false
  end
  local cmd = string.format(
    "security find-generic-password -a %s -s %s -w 2>/dev/null",
    account, TEST_SERVICE
  )
  return shell_fn(cmd)
end

local real_output = shell_for_test_service(TEST_ACCOUNT)
testkit.assert_eq((real_output:gsub("%s+$", "")), "integration-test-value", "real Keychain round-trip works")

os.execute(string.format("security delete-generic-password -a %s -s %s 2>/dev/null", TEST_ACCOUNT, TEST_SERVICE))

testkit.summary()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua hammerspoon/rephrase/test/keychain_test.lua`
Expected: FAIL with `module 'rephrase.keychain' not found`.

- [ ] **Step 3: Write the minimal implementation**

`hammerspoon/rephrase/keychain.lua`:

```lua
local shellquote = require("rephrase.shellquote")

local M = {}

M.SERVICE_NAME = "rightclick-rephrase"

local function default_shell(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return nil, false
  end
  local output = handle:read("*a")
  local ok = handle:close()
  return output, ok and true or false
end

function M.get_key(account, shell_fn)
  shell_fn = shell_fn or default_shell
  account = account or os.getenv("USER")

  local cmd = string.format(
    "security find-generic-password -a %s -s %s -w 2>/dev/null",
    shellquote.quote(account), shellquote.quote(M.SERVICE_NAME)
  )
  local output, ok = shell_fn(cmd)
  if not ok or not output or output == "" then
    return nil, "no API key found in Keychain for service " .. M.SERVICE_NAME
  end
  return (output:gsub("%s+$", ""))
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua hammerspoon/rephrase/test/keychain_test.lua`
Expected: `5 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add hammerspoon/rephrase/keychain.lua hammerspoon/rephrase/test/keychain_test.lua
git commit -m "Add keychain module with tests"
```

---

### Task 5: `providers/gemini` module

**Files:**
- Create: `hammerspoon/rephrase/providers/gemini.lua`
- Test: `hammerspoon/rephrase/test/gemini_test.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks directly (no `hs.*` calls in the pure functions; `opts.http_post`/`opts.json_encode`/`opts.json_decode` are injected by the caller — in production, Task 8's `init.lua` relies on the module's own defaults which wrap `hs.http.asyncPost`/`hs.json.encode`/`hs.json.decode`).
- Produces: `providers.gemini.build_request_body(text) -> table`, `providers.gemini.parse_response_body(decoded) -> html_or_nil, err_or_nil`, `providers.gemini.rephrase(text, opts, callback)` — used by Task 6's registry and Task 8's `init.lua`.

- [ ] **Step 1: Write the failing tests**

`hammerspoon/rephrase/test/gemini_test.lua`:

```lua
package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local gemini = require("rephrase.providers.gemini")

-- build_request_body
local body = gemini.build_request_body("Please fix this email")
testkit.assert_eq(body.contents[1].parts[1].text, "Please fix this email", "puts user text in contents")
testkit.assert_true(body.system_instruction.parts[1].text ~= nil, "includes a system_instruction")
testkit.assert_true(body.system_instruction.parts[1].text:find("HTML") ~= nil, "system instruction mentions HTML formatting")

-- parse_response_body: happy path
local decoded_ok = {
  candidates = {
    { content = { parts = { { text = "<p>Rewritten text</p>" } } } }
  }
}
local html, err = gemini.parse_response_body(decoded_ok)
testkit.assert_eq(html, "<p>Rewritten text</p>", "extracts text from first candidate")
testkit.assert_eq(err, nil, "no error on well-formed response")

-- parse_response_body: no candidates
local html2, err2 = gemini.parse_response_body({ candidates = {} })
testkit.assert_eq(html2, nil, "nil html when no candidates")
testkit.assert_true(err2 ~= nil, "error message when no candidates")

-- parse_response_body: malformed shape
local html3, err3 = gemini.parse_response_body({ candidates = { { content = {} } } })
testkit.assert_eq(html3, nil, "nil html when content has no parts")
testkit.assert_true(err3 ~= nil, "error message when content has no parts")

-- rephrase: success path with faked async http_post + fake json encode/decode
local captured_url = nil
local fake_http_post_ok = function(url, data, headers, cb)
  captured_url = url
  cb(200, "FAKE_JSON_RESPONSE")
end
local fake_json_encode = function(t) return "FAKE_JSON_REQUEST" end
local fake_json_decode = function(s)
  testkit.assert_eq(s, "FAKE_JSON_RESPONSE", "decodes the exact body the fake transport returned")
  return { candidates = { { content = { parts = { { text = "<b>Done</b>" } } } } } }
end

local got_html, got_err = nil, "not called"
gemini.rephrase("some text", {
  api_key = "TESTKEY",
  model = "gemini-3.5-flash",
  http_post = fake_http_post_ok,
  json_encode = fake_json_encode,
  json_decode = fake_json_decode,
}, function(html, err)
  got_html, got_err = html, err
end)

testkit.assert_eq(got_html, "<b>Done</b>", "rephrase resolves html on success")
testkit.assert_eq(got_err, nil, "rephrase has no error on success")
testkit.assert_true(captured_url:find("gemini%-3%.5%-flash") ~= nil, "url includes the configured model")
testkit.assert_true(captured_url:find("key=TESTKEY") ~= nil, "url includes the api key")

-- rephrase: API error status path
local fake_http_post_fail = function(url, data, headers, cb)
  cb(429, "rate limited")
end
local got_html2, got_err2 = "not called", "not called"
gemini.rephrase("some text", {
  api_key = "TESTKEY",
  http_post = fake_http_post_fail,
  json_encode = fake_json_encode,
  json_decode = function() error("should not decode on error status") end,
}, function(html, err)
  got_html2, got_err2 = html, err
end)
testkit.assert_eq(got_html2, nil, "rephrase resolves nil html on API error")
testkit.assert_true(got_err2 ~= nil and got_err2:find("429") ~= nil, "error message includes the status code")

testkit.summary()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua hammerspoon/rephrase/test/gemini_test.lua`
Expected: FAIL with `module 'rephrase.providers.gemini' not found`.

- [ ] **Step 3: Write the minimal implementation**

`hammerspoon/rephrase/providers/gemini.lua`:

```lua
local M = {}

M.SYSTEM_PROMPT = [[
You are a writing assistant embedded in a system-wide text rephrasing tool.
Rephrase the user's selected text to be clearer and better written, preserving
their intent and tone. Use minimal HTML markup only where it genuinely helps
readability: <b>...</b> to bold a key point or decision, <ul><li>...</li></ul>
for lists, and <p>...</p> to separate paragraphs. Do not use any other HTML
tags. Do not force structure that isn't there in the original text.
Respond with only the rephrased HTML fragment: no commentary, no code fences,
no explanation of what you changed.
]]

function M.build_request_body(text)
  return {
    contents = {
      { parts = { { text = text } } },
    },
    system_instruction = {
      parts = { { text = M.SYSTEM_PROMPT } },
    },
  }
end

function M.parse_response_body(decoded)
  if not decoded or not decoded.candidates or not decoded.candidates[1] then
    return nil, "no candidates in Gemini response"
  end
  local content = decoded.candidates[1].content
  if not content or not content.parts or not content.parts[1] or not content.parts[1].text then
    return nil, "malformed Gemini response: missing content.parts[1].text"
  end
  return content.parts[1].text
end

local function default_http_post(url, data, headers, cb)
  hs.http.asyncPost(url, data, headers, function(status, response_body, response_headers)
    cb(status, response_body)
  end)
end

function M.rephrase(text, opts, callback)
  opts = opts or {}
  local api_key = opts.api_key
  if not api_key then
    callback(nil, "api_key is required")
    return
  end
  local model = opts.model or "gemini-3.5-flash"
  local http_post = opts.http_post or default_http_post
  local json_encode = opts.json_encode or hs.json.encode
  local json_decode = opts.json_decode or hs.json.decode

  local body_table = M.build_request_body(text)
  local body_json = json_encode(body_table)
  local url = string.format(
    "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
    model, api_key
  )

  http_post(url, body_json, { ["Content-Type"] = "application/json" }, function(status, response_body)
    if status ~= 200 then
      callback(nil, "Gemini API error (status " .. tostring(status) .. "): " .. tostring(response_body))
      return
    end
    local decoded = json_decode(response_body)
    local html_text, err = M.parse_response_body(decoded)
    callback(html_text, err)
  end)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua hammerspoon/rephrase/test/gemini_test.lua`
Expected: `14 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add hammerspoon/rephrase/providers/gemini.lua hammerspoon/rephrase/test/gemini_test.lua
git commit -m "Add Gemini provider module with tests"
```

---

### Task 6: `providers` registry

**Files:**
- Create: `hammerspoon/rephrase/providers/init.lua`
- Test: `hammerspoon/rephrase/test/providers_test.lua`

**Interfaces:**
- Consumes: `providers.gemini` module from Task 5 (via `require("rephrase.providers.gemini")`).
- Produces: `providers.get(name) -> provider_module_or_nil, err_or_nil` — used by Task 8's `init.lua` to look up the configured provider by name, so swapping providers later means adding one module + one registry line.

- [ ] **Step 1: Write the failing tests**

`hammerspoon/rephrase/test/providers_test.lua`:

```lua
package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local providers = require("rephrase.providers")
local gemini = require("rephrase.providers.gemini")

local provider, err = providers.get("gemini")
testkit.assert_eq(provider, gemini, "returns the gemini module for name 'gemini'")
testkit.assert_eq(err, nil, "no error for a known provider")

local provider2, err2 = providers.get("nonexistent-provider")
testkit.assert_eq(provider2, nil, "returns nil for an unknown provider")
testkit.assert_true(err2 ~= nil and err2:find("nonexistent%-provider") ~= nil, "error names the unknown provider")

testkit.summary()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua hammerspoon/rephrase/test/providers_test.lua`
Expected: FAIL with `module 'rephrase.providers' not found`.

- [ ] **Step 3: Write the minimal implementation**

`hammerspoon/rephrase/providers/init.lua`:

```lua
local M = {}

M.registry = {
  gemini = require("rephrase.providers.gemini"),
}

function M.get(name)
  local provider = M.registry[name]
  if not provider then
    return nil, "unknown provider: " .. tostring(name)
  end
  return provider
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua hammerspoon/rephrase/test/providers_test.lua`
Expected: `4 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add hammerspoon/rephrase/providers/init.lua hammerspoon/rephrase/test/providers_test.lua
git commit -m "Add provider registry with tests"
```

---

### Task 7: `clipboard` module

**Files:**
- Create: `hammerspoon/rephrase/clipboard.lua`
- Test: `hammerspoon/rephrase/test/clipboard_test.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks (DI'd against a fake pasteboard object in tests; defaults to the real `hs.pasteboard` in production, only touched when actually invoked inside Hammerspoon).
- Produces: `clipboard.save`, `clipboard.restore`, `clipboard.read_plain`, `clipboard.write_rich`, `clipboard.write_plain` — used by Task 8's `init.lua`.

- [ ] **Step 1: Write the failing tests**

`hammerspoon/rephrase/test/clipboard_test.lua`:

```lua
package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local clipboard = require("rephrase.clipboard")

local function make_fake_pb(initial_all_data, initial_string)
  local fake = {
    _all_data = initial_all_data,
    _string = initial_string,
    _last_written = nil,
  }
  fake.readAllData = function() return fake._all_data end
  fake.writeAllData = function(t) fake._last_written = t; return true end
  fake.readString = function() return fake._string end
  return fake
end

-- save / restore round-trip
local pb1 = make_fake_pb({ ["public.utf8-plain-text"] = "original clipboard" }, "original clipboard")
local saved = clipboard.save(pb1)
testkit.assert_eq(saved["public.utf8-plain-text"], "original clipboard", "save reads all pasteboard data")

local ok = clipboard.restore(saved, pb1)
testkit.assert_true(ok, "restore reports success")
testkit.assert_eq(pb1._last_written["public.utf8-plain-text"], "original clipboard", "restore writes back the saved data")

-- read_plain
local pb2 = make_fake_pb({}, "selected text")
testkit.assert_eq(clipboard.read_plain(pb2), "selected text", "read_plain returns the current string")

-- write_rich
local pb3 = make_fake_pb({}, nil)
clipboard.write_rich("{\\rtf1 fake}", "fake plain", pb3)
testkit.assert_eq(pb3._last_written["public.rtf"], "{\\rtf1 fake}", "write_rich sets the RTF UTI")
testkit.assert_eq(pb3._last_written["public.utf8-plain-text"], "fake plain", "write_rich sets the plain-text UTI")

-- write_plain
local pb4 = make_fake_pb({}, nil)
clipboard.write_plain("just plain", pb4)
testkit.assert_eq(pb4._last_written["public.utf8-plain-text"], "just plain", "write_plain sets only the plain-text UTI")
testkit.assert_eq(pb4._last_written["public.rtf"], nil, "write_plain does not set an RTF UTI")

testkit.summary()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua hammerspoon/rephrase/test/clipboard_test.lua`
Expected: FAIL with `module 'rephrase.clipboard' not found`.

- [ ] **Step 3: Write the minimal implementation**

`hammerspoon/rephrase/clipboard.lua`:

```lua
local M = {}

function M.save(pb)
  pb = pb or hs.pasteboard
  return pb.readAllData()
end

function M.restore(saved, pb)
  pb = pb or hs.pasteboard
  return pb.writeAllData(saved)
end

function M.read_plain(pb)
  pb = pb or hs.pasteboard
  return pb.readString()
end

function M.write_rich(rtf_bytes, plain_text, pb)
  pb = pb or hs.pasteboard
  return pb.writeAllData({
    ["public.rtf"] = rtf_bytes,
    ["public.utf8-plain-text"] = plain_text,
  })
end

function M.write_plain(plain_text, pb)
  pb = pb or hs.pasteboard
  return pb.writeAllData({
    ["public.utf8-plain-text"] = plain_text,
  })
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua hammerspoon/rephrase/test/clipboard_test.lua`
Expected: `7 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add hammerspoon/rephrase/clipboard.lua hammerspoon/rephrase/test/clipboard_test.lua
git commit -m "Add clipboard module with tests"
```

---

### Task 8: `init.lua` orchestration + test runner + manual verification

**Files:**
- Create: `hammerspoon/rephrase/init.lua`
- Create: `hammerspoon/rephrase/test/run_tests.sh`
- Modify: `README.md` (add manual verification checklist)

**Interfaces:**
- Consumes: `clipboard` (Task 7), `html_to_rtf` (Task 3), `keychain` (Task 4), `providers` (Task 6) — all via `require("rephrase.<name>")`.
- Produces: the live hotkey binding; nothing downstream depends on this module (it's the top of the dependency graph).

This task's code is Hammerspoon-API-heavy glue (`hs.hotkey`, `hs.eventtap`, `hs.alert`, `hs.timer`) and is not unit-tested — it's verified with the manual checklist in Step 4, matching the spec's Testing/Verification section.

- [ ] **Step 1: Write the test runner script**

`hammerspoon/rephrase/test/run_tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."

for f in hammerspoon/rephrase/test/*_test.lua; do
  echo "=== $f ==="
  lua "$f"
done
```

Run: `chmod +x hammerspoon/rephrase/test/run_tests.sh && ./hammerspoon/rephrase/test/run_tests.sh`
Expected: all six `*_test.lua` files print their `N passed, 0 failed` line with no `FAIL` lines anywhere in the output.

- [ ] **Step 2: Write `init.lua`**

`hammerspoon/rephrase/init.lua`:

```lua
local keychain = require("rephrase.keychain")
local clipboard = require("rephrase.clipboard")
local html_to_rtf = require("rephrase.html_to_rtf")
local providers = require("rephrase.providers")

local config_ok, config = pcall(require, "rephrase.config")
if not config_ok then
  hs.alert.show("rephrase: missing config.lua — copy config.lua.example and edit it")
  return {}
end

local M = {}

function M.rephrase_selection()
  local saved = clipboard.save()

  hs.eventtap.keyStroke({ "cmd" }, "c")

  hs.timer.doAfter(0.2, function()
    local selected = clipboard.read_plain()
    if not selected or selected == "" then
      hs.alert.show("Rephrase: nothing selected")
      clipboard.restore(saved)
      return
    end

    local max_chars = config.max_input_chars or 8000
    if #selected > max_chars then
      hs.alert.show("Rephrase: selection too long (max " .. max_chars .. " characters)")
      clipboard.restore(saved)
      return
    end

    hs.alert.show("Rephrasing…")

    local provider, provider_err = providers.get(config.provider)
    if not provider then
      hs.alert.show("Rephrase error: " .. provider_err)
      clipboard.restore(saved)
      return
    end

    local api_key, key_err = keychain.get_key()
    if not api_key then
      hs.alert.show("Rephrase error: " .. key_err)
      clipboard.restore(saved)
      return
    end

    provider.rephrase(selected, { api_key = api_key, model = config.model }, function(html, rephrase_err)
      if not html then
        hs.alert.show("Rephrase error: " .. tostring(rephrase_err))
        clipboard.restore(saved)
        return
      end

      local rtf = html_to_rtf.convert_to_rtf(html)
      local plain = html_to_rtf.strip_tags(html)

      if rtf then
        clipboard.write_rich(rtf, plain)
      else
        clipboard.write_plain(plain)
      end

      hs.eventtap.keyStroke({ "cmd" }, "v")

      hs.timer.doAfter(1, function()
        clipboard.restore(saved)
      end)
    end)
  end)
end

local mods = (config.hotkey and config.hotkey.mods) or { "cmd", "alt" }
local key = (config.hotkey and config.hotkey.key) or "R"
hs.hotkey.bind(mods, key, M.rephrase_selection)

return M
```

- [ ] **Step 3: Wire it into the real Hammerspoon config**

Run:
```bash
ln -sf "$(pwd)/hammerspoon/rephrase" ~/.hammerspoon/rephrase
grep -q 'require("rephrase.init")' ~/.hammerspoon/init.lua 2>/dev/null || echo 'require("rephrase.init")' >> ~/.hammerspoon/init.lua
cp -n hammerspoon/rephrase/config.lua.example hammerspoon/rephrase/config.lua
```

Then set the real Gemini key in Keychain (skip if already done from the README):
`security add-generic-password -a "$USER" -s "rightclick-rephrase" -w "YOUR_REAL_KEY"`

Reload Hammerspoon's config (menu bar icon -> Reload Config, or `hs -c "hs.reload()"` if the Hammerspoon CLI is installed).

- [ ] **Step 4: Manual end-to-end verification checklist**

Add this checklist to `README.md` under a new "## Manual verification" heading, then run through it once by hand:

```markdown
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
```

- [ ] **Step 5: Commit**

```bash
git add hammerspoon/rephrase/init.lua hammerspoon/rephrase/test/run_tests.sh README.md
git commit -m "Add init.lua orchestration, test runner, and manual verification checklist"
```
