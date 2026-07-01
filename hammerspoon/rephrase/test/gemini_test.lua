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
