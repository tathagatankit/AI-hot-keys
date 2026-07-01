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
