-- tests/test_tween.lua — run with `lua5.4 tests/test_tween.lua` from the repo root.
-- Copre il tweening delle pose introdotto in v0.7: nessuno snap, convergenza
-- esatta al target, redirect mid-transition che riparte dalla posa corrente,
-- ogni curva di easing finita (niente NaN/inf) e una reazione che interrompe
-- un'altra senza lasciare il rig in stato inconsistente.

package.path = package.path .. ";./?.lua"

love = {
  graphics = {
    newImage = function(path) return { path = path } end,
    push = function() end, pop = function() end, translate = function() end,
    rotate = function() end, scale = function() end, setColor = function() end,
    draw = function() end, circle = function() end, polygon = function() end,
    rectangle = function() end, stencil = function(fn) if fn then fn() end end,
    setStencilTest = function() end,
  },
  filesystem = {
    read = function(path)
      local f = io.open(path, "r"); if not f then return nil end
      local c = f:read("*a"); f:close(); return c
    end,
  },
}

local Rig = dofile("minoru/rig.lua")

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("  FAIL: " .. msg)
  end
end

-- 1. nessuno snap: dopo un dt piccolo la posa e' strettamente tra start e target
do
  local r = Rig.new("minoru/assets/")
  r:setPose({ shoulderL = 0.5 }, { duration = 0.5, ease = "linear" })
  check(r.poseT == 0, "poseT resettato a 0 quando si retargetta")
  r:update(0.05)
  local v = r.pose.shoulderL
  check(v > 0.04 and v < 0.06, "linear 10% dt -> ~0.05 (got " .. tostring(v) .. ")")
  check(v < 0.5, "la posa non e' scattata al target dopo un frame")
end

-- 2. convergenza esatta a t=1
do
  local r = Rig.new("minoru/assets/")
  r:setPose({ shoulderL = 0.42, elbowR = -0.7 }, { duration = 0.1 })
  for _ = 1, 20 do r:update(0.02) end
  check(math.abs(r.pose.shoulderL - 0.42) < 1e-9, "shoulderL converge esatto")
  check(math.abs(r.pose.elbowR - (-0.7)) < 1e-9, "elbowR converge esatto")
  check(r.poseT == 1, "poseT arriva a 1")
end

-- 3. redirect mid-transition: niente snap-back allo start originale
do
  local r = Rig.new("minoru/assets/")
  r:setPose({ shoulderL = 1.0 }, { duration = 1.0, ease = "linear" })
  r:update(0.5)
  local mid = r.pose.shoulderL
  check(math.abs(mid - 0.5) < 0.05, "mid-transition ~0.5 (got " .. tostring(mid) .. ")")
  r:setPose({ shoulderL = 0.2 }, { duration = 1.0, ease = "linear" })
  r:update(0.001)
  local after = r.pose.shoulderL
  check(math.abs(after - mid) < 0.02,
    "il redirect parte dalla posa corrente, non dallo start/target vecchio (got "
    .. tostring(after) .. ", atteso ~" .. tostring(mid) .. ")")
end

-- 4. ogni curva di easing e' finita per tutti i t
do
  local eases = { "linear", "easeOutQuad", "easeOutCubic", "easeInOutSine", "easeOutBack", "easeOutElastic" }
  for _, easeName in ipairs(eases) do
    local r = Rig.new("minoru/assets/")
    r:setPose({ shoulderL = 1.0 }, { duration = 0.3, ease = easeName })
    local broke = false
    for _ = 1, 100 do
      r:update(0.005)
      local v = r.pose.shoulderL
      if v ~= v or v == math.huge or v == -math.huge then
        failures = failures + 1
        print("  FAIL: ease=" .. easeName .. " ha prodotto un valore non finito: " .. tostring(v))
        broke = true
        break
      end
    end
    if not broke then
      check(math.abs(r.pose.shoulderL - 1.0) < 1e-6, "ease=" .. easeName .. " converge al target")
    end
  end
end

-- 5. una reazione che ne interrompe un'altra non lascia il rig bloccato
do
  local r = Rig.new("minoru/assets/")
  r:reactHappy()
  r:update(0.05)
  r:reactAngry()
  for _ = 1, 200 do r:update(0.016) end
  check(r.poseT == 1, "poseT si assesta dopo la reazione interrompente")
  check(r.mood == "angry", "il mood finale e' quello della reazione interrompente")
end

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All tween tests passed.")
end
