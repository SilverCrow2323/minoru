-- tests/test_visor.lua — run with `lua5.4 tests/test_visor.lua` from the repo root.
-- This exists because of a real bug: `(x/0.82)^2.2` with a negative x is NaN
-- in Lua (fractional power of a negative base), which silently made half of
-- the "standard" visor line disappear — it LOOKED like the line was shifted
-- to the right, when actually the left half just wasn't drawing. This test
-- calls every mood's shape math directly and fails loudly on any NaN/inf,
-- so that class of bug can't silently ship again.

package.path = package.path .. ";./?.lua;./minoru/?.lua"

local badValues = 0
local function checkNum(n, ctx)
  if n ~= n or n == math.huge or n == -math.huge then -- n~=n catches NaN
    badValues = badValues + 1
    print(string.format("  BAD VALUE: %s -> %s", ctx, tostring(n)))
  end
end

love = {
  graphics = {
    newImage = function(path) return { path = path } end,
    push = function() end, pop = function() end, translate = function() end,
    rotate = function() end, scale = function() end,
    setColor = function(r, g, b, a)
      checkNum(r, "setColor r"); checkNum(g, "setColor g")
      checkNum(b, "setColor b"); checkNum(a or 1, "setColor a")
    end,
    circle = function(mode, x, y, r) checkNum(x, "circle x"); checkNum(y, "circle y"); checkNum(r, "circle r") end,
    rectangle = function(mode, x, y, w, h)
      checkNum(x, "rect x"); checkNum(y, "rect y"); checkNum(w, "rect w"); checkNum(h, "rect h")
    end,
    polygon = function(mode, ...)
      local pts = { ... }
      for i, v in ipairs(pts) do checkNum(v, "polygon coord #" .. i) end
    end,
    stencil = function(fn) if fn then fn() end end,
    setStencilTest = function() end,
    draw = function() end,
  },
}

local Visor = dofile("minoru/visor.lua")

local moods = {}
for name, _ in pairs(Visor.COLOR) do moods[#moods + 1] = name end
table.sort(moods)

local cx, cy, r = 420, 503, 160
for _, mood in ipairs(moods) do
  for _, t in ipairs({ 0, 0.37, 1.5, 7.2, 33.9 }) do
    for _, amp in ipairs({ 0, 0.2, 0.5, 1.0 }) do
      local ok, err = pcall(Visor.draw, cx, cy, r, {
        mood = mood, processing = false, blend = 1, t = t,
        opts = { amp = amp, glitchSeed = math.floor(t * 12) },
      })
      if not ok then
        badValues = badValues + 1
        print(string.format("  ERROR mood=%s t=%s amp=%s -> %s", mood, t, amp, tostring(err)))
      end
    end
  end
end

-- also exercise the processing-dots path and a mid-crossfade blend
for _, t in ipairs({ 0, 1.1, 4.4 }) do
  Visor.draw(cx, cy, r, { mood = "standard", processing = true, blend = 1, t = t, opts = {} })
  Visor.draw(cx, cy, r, {
    mood = "angry", prevMood = "standard", blend = 0.5, t = t,
    opts = {}, prevOpts = {},
  })
end

print(string.format("\nChecked %d moods x 5 time values x 4 amplitudes.", #moods))
if badValues > 0 then
  print(badValues .. " BAD VALUE(S) FOUND — see above.")
  os.exit(1)
else
  print("No NaN/inf reached any draw call. OK.")
end
