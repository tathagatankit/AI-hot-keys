package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local providers = require("rephrase.providers")
local gemini = require("rephrase.providers.gemini")

local provider, err = providers.get("gemini")
testkit.assert_eq(provider, gemini, "returns the gemini module for name 'gemini'")
testkit.assert_eq(err, nil, "no error for a known provider")

local provider2, err2 = providers.get("nonexistent-provider")
testkit.assert_eq(provider2, nil, "returns nil for an unknown provider")
testkit.assert_true(err2 ~= nil and err2:find("nonexistent%-provider") ~= nil, "error names the unknown provider")

testkit.summary()
