-- tests/test_dialogue.lua — run with `lua5.4 tests/test_dialogue.lua` from the repo root.
-- Regression test for a real crash: love.graphics.printf(fullText:sub(1,shown))
-- sliced by BYTE count, which occasionally cut a multi-byte UTF-8 character
-- (e.g. "⁶", or any Italian accented letter) in half mid-typewriter-effect,
-- throwing "UTF-8 decoding error: Not enough space" inside real LÖVE. This
-- reproduces the exact frame-by-frame stepping that triggered it.

package.path = package.path .. ";./?.lua"

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("  FAIL: " .. msg)
  end
end

love = {
  graphics = {
    newFont = function() return {} end,
    getWidth = function() return 800 end, getHeight = function() return 600 end,
    setColor = function() end, setFont = function() end, setLineWidth = function() end,
    rectangle = function() end, line = function() end,
    print = function() end,
    printf = function(text)
      -- mirror what real love.graphics.printf does: reject invalid/incomplete UTF-8
      local ok = utf8.len(text)
      if not ok then
        failures = failures + 1
        print("  FAIL: printf received invalid/truncated UTF-8: " .. string.format("%q", text))
      end
    end,
  },
}

local Dialogue = dofile("minoru/dialogue.lua")

local samples = {
  "Minoru\xE2\x81\xB6 sta parlando adesso.",              -- the ⁶ character
  "Perché non ce l'hai detto più chiaramente, così può capirlo tutti quanti?", -- heavy Italian accents
  "città, così, però, già, più: tutte parole con caratteri multi-byte di fila",
  "",  -- edge case: empty string
  "a", -- edge case: single ascii char
}

for _, text in ipairs(samples) do
  local d = Dialogue.new({ charsPerSec = 1000 }) -- fast, to step through many shown-counts quickly
  d:say("Minoru\xE2\x81\xB6", text)
  -- step frame by frame with a tiny dt so `shown` advances one character (or
  -- fewer) at a time, hitting every possible mid-string cut point
  for _ = 1, 200 do
    d:update(1 / 1000)
    d:draw()
    if not d:isTyping() then break end
  end
  check(d.shown == d.fullLen, "typewriter reaches the end for: " .. string.format("%q", text))
end

-- also check :skip() and :advance() land on a valid cut immediately
local d2 = Dialogue.new({})
d2:say("Minoru\xE2\x81\xB6", "città più già però")
d2:skip()
d2:draw()
check(d2.shown == d2.fullLen, "skip() reveals the full text")

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All dialogue tests passed.")
end
