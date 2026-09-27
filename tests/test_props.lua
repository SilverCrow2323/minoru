-- tests/test_props.lua — lua5.4 tests/test_props.lua
-- I prop procedurali (minoru/props.lua) non devono mai passare NaN/inf a
-- love.graphics, non devono esplodere se le primitive mancano, e la lista
-- Props.names deve corrispondere alle funzioni effettivamente definite.

package.path = package.path .. ";./?.lua"

local failures = 0
local function check(cond, msg)
  if not cond then failures = failures + 1; print("  FAIL: " .. msg) end
end
local function checkNum(n, ctx)
  if n ~= n or n == math.huge or n == -math.huge then
    failures = failures + 1
    print("  FAIL: " .. ctx .. " = " .. tostring(n))
  end
end

love = {
  graphics = {
    setColor = function(r, g, b, a)
      checkNum(r, "setColor r"); checkNum(g, "setColor g")
      checkNum(b, "setColor b"); checkNum(a or 1, "setColor a")
    end,
    setLineWidth = function(w) checkNum(w, "setLineWidth") end,
    circle = function(_, x, y, r)
      checkNum(x, "circle x"); checkNum(y, "circle y"); checkNum(r, "circle r")
    end,
    rectangle = function(_, x, y, w, h)
      checkNum(x, "rect x"); checkNum(y, "rect y")
      checkNum(w, "rect w"); checkNum(h, "rect h")
    end,
    polygon = function(_, ...)
      for i, v in ipairs({ ... }) do checkNum(v, "polygon #" .. i) end
    end,
    line = function(...)
      for i, v in ipairs({ ... }) do checkNum(v, "line #" .. i) end
    end,
    push = function() end, pop = function() end,
    translate = function() end, rotate = function() end, scale = function() end,
  },
}

local Props = dofile("minoru/props.lua")

-- 1. ogni nome in Props.names ha una funzione
for name, _ in pairs(Props.names) do
  check(type(Props[name]) == "function",
    "Props.names contiene '" .. name .. "' ma Props." .. name .. " non e' una funzione")
end

-- 2. ogni funzione chiamabile senza errori e senza NaN
for name, _ in pairs(Props.names) do
  local ok, err = pcall(Props[name])
  check(ok, "Props." .. name .. "() non deve errore: " .. tostring(err))
end

-- 3. Props.exists
check(Props.exists("napoleon") == true, "Props.exists('napoleon') -> true")
check(Props.exists("nope")     == false, "Props.exists('nope') -> false")
check(Props.exists(nil)        == false, "Props.exists(nil) -> false")
check(Props.exists({})         == false, "Props.exists({}) -> false")

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All props tests passed.")
end
