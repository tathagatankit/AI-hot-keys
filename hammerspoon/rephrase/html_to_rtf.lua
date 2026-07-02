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
