local M = {}

function M.quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

return M
