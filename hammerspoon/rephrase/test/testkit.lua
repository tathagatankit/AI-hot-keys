local M = {}
local pass_count = 0
local fail_count = 0

function M.assert_eq(actual, expected, message)
  if actual == expected then
    pass_count = pass_count + 1
  else
    fail_count = fail_count + 1
    print(string.format("FAIL: %s\n  expected: %s\n  actual:   %s",
      message or "", tostring(expected), tostring(actual)))
  end
end

function M.assert_true(value, message)
  M.assert_eq(value and true or false, true, message)
end

function M.summary()
  print(string.format("\n%d passed, %d failed", pass_count, fail_count))
  if fail_count > 0 then
    os.exit(1)
  end
end

return M
