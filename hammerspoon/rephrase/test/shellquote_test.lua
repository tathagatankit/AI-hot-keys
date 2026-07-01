package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local shellquote = require("rephrase.shellquote")

testkit.assert_eq(shellquote.quote("hello"), "'hello'", "plain string")
testkit.assert_eq(shellquote.quote("hello world"), "'hello world'", "string with space")
testkit.assert_eq(shellquote.quote("it's"), "'it'\\''s'", "string with single quote")
testkit.assert_eq(shellquote.quote(""), "''", "empty string")

testkit.summary()
