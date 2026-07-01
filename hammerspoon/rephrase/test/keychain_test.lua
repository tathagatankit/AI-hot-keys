package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local keychain = require("rephrase.keychain")

-- get_key with a fake shell_fn
local seen_cmd = nil
local fake_shell_ok = function(cmd)
  seen_cmd = cmd
  return "sk-fake-key-123\n", true
end
local key, err = keychain.get_key("testuser", fake_shell_ok)
testkit.assert_eq(key, "sk-fake-key-123", "trims trailing newline")
testkit.assert_eq(err, nil, "no error on success")
testkit.assert_true(seen_cmd:find("security find%-generic%-password") ~= nil, "command invokes security find-generic-password")
testkit.assert_true(seen_cmd:find(keychain.SERVICE_NAME, 1, true) ~= nil, "command references the service name")

local fake_shell_fail = function(cmd)
  return "", false
end
local key2, err2 = keychain.get_key("testuser", fake_shell_fail)
testkit.assert_eq(key2, nil, "returns nil when not found")
testkit.assert_true(err2 ~= nil, "returns an error message when not found")

-- integration test against a real, distinct test-only Keychain entry
local TEST_SERVICE = "rightclick-rephrase-planitest"
local TEST_ACCOUNT = os.getenv("USER")
os.execute(string.format(
  "security add-generic-password -a %s -s %s -w %s -U 2>/dev/null",
  TEST_ACCOUNT, TEST_SERVICE, "integration-test-value"
))

local function shell_for_test_service(account, shell_fn)
  shell_fn = shell_fn or function(cmd)
    local handle = io.popen(cmd)
    if not handle then
      return nil, false
    end
    local output = handle:read("*a")
    local ok = handle:close()
    return output, ok and true or false
  end
  local cmd = string.format(
    "security find-generic-password -a %s -s %s -w 2>/dev/null",
    account, TEST_SERVICE
  )
  return shell_fn(cmd)
end

local real_output = shell_for_test_service(TEST_ACCOUNT)
testkit.assert_eq((real_output:gsub("%s+$", "")), "integration-test-value", "real Keychain round-trip works")

os.execute(string.format("security delete-generic-password -a %s -s %s 2>/dev/null", TEST_ACCOUNT, TEST_SERVICE))

testkit.summary()
