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
