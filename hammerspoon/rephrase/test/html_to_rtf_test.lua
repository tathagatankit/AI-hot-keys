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
