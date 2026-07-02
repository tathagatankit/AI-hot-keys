package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local clipboard = require("rephrase.clipboard")

local function make_fake_pb(initial_all_data, initial_string, initial_change_count)
  local fake = {
    _all_data = initial_all_data,
    _string = initial_string,
    _last_written = nil,
    _change_count = initial_change_count or 0,
  }
  fake.readAllData = function() return fake._all_data end
  fake.writeAllData = function(t)
    fake._last_written = t
    fake._change_count = fake._change_count + 1
    return true
  end
  fake.readString = function() return fake._string end
  fake.changeCount = function() return fake._change_count end
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

-- change_count
local pb5 = make_fake_pb({}, "unchanged", 5)
testkit.assert_eq(clipboard.change_count(pb5), 5, "change_count returns the pasteboard's current change count")
clipboard.write_plain("new content", pb5)
testkit.assert_eq(clipboard.change_count(pb5), 6, "change_count reflects a write that just happened")

testkit.summary()
