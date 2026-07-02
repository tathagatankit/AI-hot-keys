local M = {}

function M.bold(text)
  local result = {}
  for _, code in utf8.codes(text) do
    local bold_code
    if code >= 0x41 and code <= 0x5A then
      bold_code = 0x1D400 + (code - 0x41)
    elseif code >= 0x61 and code <= 0x7A then
      bold_code = 0x1D41A + (code - 0x61)
    elseif code >= 0x30 and code <= 0x39 then
      bold_code = 0x1D7CE + (code - 0x30)
    end
    table.insert(result, utf8.char(bold_code or code))
  end
  return table.concat(result)
end

function M.convert(html_fragment)
  local text = html_fragment

  text = text:gsub("<b>(.-)</b>", function(inner)
    return M.bold(inner)
  end)

  text = text:gsub("<li>(.-)</li>", function(inner)
    return "• " .. inner .. "\n"
  end)
  text = text:gsub("</?[uo]l>", "")

  text = text:gsub("<p>(.-)</p>", function(inner)
    return inner .. "\n\n"
  end)

  text = text:gsub("<[^>]*>", "")

  text = text:gsub("&nbsp;", " ")
  text = text:gsub("&amp;", "&")
  text = text:gsub("&lt;", "<")
  text = text:gsub("&gt;", ">")
  text = text:gsub("&quot;", '"')
  text = text:gsub("&#39;", "'")

  text = text:gsub("%s+$", "")

  return text
end

return M
