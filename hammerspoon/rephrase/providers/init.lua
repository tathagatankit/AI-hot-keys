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
