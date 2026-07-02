package.path = "./hammerspoon/?.lua;./hammerspoon/?/init.lua;" .. package.path

local testkit = require("rephrase.test.testkit")
local unicode_format = require("rephrase.unicode_format")

-- bold(): pinned against the Unicode "Mathematical Alphanumeric Symbols" block
-- (U+1D400 MATHEMATICAL BOLD CAPITAL A, U+1D41A MATHEMATICAL BOLD SMALL A,
--  U+1D7CE MATHEMATICAL BOLD DIGIT ZERO), independent of the module's own math.
testkit.assert_eq(unicode_format.bold("A"), utf8.char(0x1D400), "bolds uppercase A")
testkit.assert_eq(unicode_format.bold("Z"), utf8.char(0x1D419), "bolds uppercase Z")
testkit.assert_eq(unicode_format.bold("a"), utf8.char(0x1D41A), "bolds lowercase a")
testkit.assert_eq(unicode_format.bold("z"), utf8.char(0x1D433), "bolds lowercase z")
testkit.assert_eq(unicode_format.bold("0"), utf8.char(0x1D7CE), "bolds digit 0")
testkit.assert_eq(unicode_format.bold("9"), utf8.char(0x1D7D7), "bolds digit 9")
testkit.assert_eq(
  unicode_format.bold("Aa0!"),
  utf8.char(0x1D400) .. utf8.char(0x1D41A) .. utf8.char(0x1D7CE) .. "!",
  "bolds letters and digits, leaves punctuation untouched"
)
testkit.assert_eq(unicode_format.bold(""), "", "bolds empty string to empty string")

-- convert()
testkit.assert_eq(
  unicode_format.convert("<p>Hello <b>world</b></p>"),
  "Hello " .. unicode_format.bold("world"),
  "bolds an inline <b> span within a paragraph"
)

testkit.assert_eq(
  unicode_format.convert("<ul><li>First</li><li>Second</li></ul>"),
  "• First\n• Second",
  "converts list items to bullet-prefixed lines, no wrapper tags, no trailing newline"
)

testkit.assert_eq(
  unicode_format.convert("<p>First paragraph.</p><p>Second paragraph.</p>"),
  "First paragraph.\n\nSecond paragraph.",
  "separates paragraphs with a blank line, no trailing blank line"
)

testkit.assert_eq(
  unicode_format.convert("Plain text, no tags."),
  "Plain text, no tags.",
  "leaves untagged plain text unchanged"
)

testkit.assert_eq(
  unicode_format.convert("<p>A&amp;B&nbsp;&nbsp;C &lt;tag&gt; &quot;q&quot; it&#39;s</p>"),
  'A&B  C <tag> "q" it\'s',
  "unescapes common HTML entities"
)

testkit.summary()
