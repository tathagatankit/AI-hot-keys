local keychain = require("rephrase.keychain")
local clipboard = require("rephrase.clipboard")
local html_to_rtf = require("rephrase.html_to_rtf")
local unicode_format = require("rephrase.unicode_format")
local providers = require("rephrase.providers")

local config_ok, config = pcall(require, "rephrase.config")
if not config_ok then
  hs.alert.show("rephrase: missing config.lua — copy config.lua.example and edit it")
  return {}
end

-- Registers Hammerspoon with macOS Login Items so it (and this tool) comes
-- back automatically after a restart/logout, not just while it happens to
-- already be running. Idempotent -- safe to call on every config load.
hs.autoLaunch(true)

local M = {}

local pending_restore_timer = nil

local function cancel_pending_restore()
  if pending_restore_timer then
    pending_restore_timer:stop()
    pending_restore_timer = nil
  end
end

function M.rephrase_selection()
  cancel_pending_restore()

  local saved = clipboard.save()
  local before_count = clipboard.change_count()

  hs.eventtap.keyStroke({ "cmd" }, "c")

  hs.timer.doAfter(0.2, function()
    local after_count = clipboard.change_count()
    local selected = clipboard.read_plain()
    if after_count == before_count or not selected or selected == "" then
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

      if config.format_mode == "unicode" then
        clipboard.write_plain(unicode_format.convert(html))
      else
        local rtf = html_to_rtf.convert_to_rtf(html)
        local plain = html_to_rtf.strip_tags(html)

        if rtf then
          clipboard.write_rich(rtf, plain)
        else
          clipboard.write_plain(plain)
        end
      end

      hs.eventtap.keyStroke({ "cmd" }, "v")

      pending_restore_timer = hs.timer.doAfter(1, function()
        pending_restore_timer = nil
        clipboard.restore(saved)
      end)
    end)
  end)
end

local mods = (config.hotkey and config.hotkey.mods) or { "cmd", "alt" }
local key = (config.hotkey and config.hotkey.key) or "R"
hs.hotkey.bind(mods, key, M.rephrase_selection)

return M
