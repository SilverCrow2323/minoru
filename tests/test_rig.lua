-- tests/test_rig.lua — esegui con `lua5.4 tests/test_rig.lua` dalla root.
-- Stubba love.graphics/love.filesystem per esercitare la forward-kinematics
-- di rig.lua (braccio -> palmo -> dita a 3 falangi) senza un vero contesto
-- LÖVE, e ASSERISCE che i pivot world disegnati combacino con la matematica
-- calcolata direttamente da anchors.json. (Prima stampava solo "confronta a
-- occhio" — non era un test.)

package.path = package.path .. ";./?.lua"

local function matMul(a, b)
  return {
    a = a.a*b.a + a.c*b.b, b = a.b*b.a + a.d*b.b,
    c = a.a*b.c + a.c*b.d, d = a.b*b.c + a.d*b.d,
    tx = a.a*b.tx + a.c*b.ty + a.tx, ty = a.b*b.tx + a.d*b.ty + a.ty,
  }
end
local function mk(a,b,c,d,tx,ty) return {a=a,b=b,c=c,d=d,tx=tx,ty=ty} end
local IDENT = mk(1,0,0,1,0,0)

local stack = { IDENT }
local function top() return stack[#stack] end
local function apply(m, x, y) return m.a*x + m.c*y + m.tx, m.b*x + m.d*y + m.ty end

local drawLog = {}
local fakeImages = {}
love = {
  graphics = {
    newImage = function(path)
      fakeImages[path] = fakeImages[path] or { path = path }
      return fakeImages[path]
    end,
    push = function() stack[#stack+1] = top() end,
    pop = function() stack[#stack] = nil end,
    translate = function(x, y) stack[#stack] = matMul(top(), mk(1,0,0,1,x,y)) end,
    rotate = function(r)
      local c, s = math.cos(r), math.sin(r)
      stack[#stack] = matMul(top(), mk(c,s,-s,c,0,0))
    end,
    scale = function(sx, sy)
      sy = sy or sx
      stack[#stack] = matMul(top(), mk(sx,0,0,sy,0,0))
    end,
    setColor = function() end, circle = function() end, polygon = function() end,
    rectangle = function() end,
    stencil = function(fn) if fn then fn() end end,
    setStencilTest = function() end,
    draw = function(img, x, y, r, sx, sy, ox, oy)
      x, y = x or 0, y or 0; r = r or 0; sx = sx or 1; sy = sy or sx; ox, oy = ox or 0, oy or 0
      local c, s = math.cos(r), math.sin(r)
      local m = mk(1,0,0,1,x,y)
      m = matMul(m, mk(c,s,-s,c,0,0))
      m = matMul(m, mk(sx,0,0,sy,0,0))
      m = matMul(m, mk(1,0,0,1,-ox,-oy))
      local world = matMul(top(), m)
      local px, py = apply(world, ox, oy)
      drawLog[#drawLog+1] = { img = img.path, pivot_world = {px, py} }
    end,
  },
  filesystem = {
    read = function(path)
      local f = io.open(path, "r")
      if not f then return nil end
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
local function approx(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end

local rig = Rig.new("minoru/assets/")
local a = rig.anchors
rig.pose.gripL, rig.pose.gripR = 0, 0
rig.trembleAmp = 0
rig.talking = false
rig.autoTalk = false
rig.poseT = 1
rig.idleT = 0 -- spegne il bob per i controlli FK

-- 1. braccia giu' dritte
drawLog = {}
rig:draw(100, 100, 1)

local lenU = a.upper_arm.pivot_bottom[2] - a.upper_arm.pivot_top[2]
local lenF = a.forearm.pivot_bottom[2] - a.forearm.pivot_top[2]
local expPalmX = 100 + a.helmet.shoulder_l[1]
local expPalmY = 100 + a.helmet.shoulder_l[2] + lenU + lenF

local palmEntry
for _, e in ipairs(drawLog) do
  if e.img:match("palm") then palmEntry = e; break end
end
check(palmEntry ~= nil, "il palmo sinistro e' stato disegnato")
if palmEntry then
  check(approx(palmEntry.pivot_world[1], expPalmX, 0.5),
    string.format("palm sx X ~%.2f (got %.2f)", expPalmX, palmEntry.pivot_world[1]))
  check(approx(palmEntry.pivot_world[2], expPalmY, 0.5),
    string.format("palm sx Y ~%.2f (got %.2f)", expPalmY, palmEntry.pivot_world[2]))
end

-- 2. braccio destro specchiato
-- Il braccio sinistro viene disegnato per primo, quindi la PRIMA entry
-- "palm" nel log e' il palmo sinistro. Il destro e' la SECONDA.
drawLog = {}
rig.lastX, rig.lastY = nil, nil
rig:draw(100, 100, 1)
local palmCount = 0
local palmREntry
for _, e in ipairs(drawLog) do
  if e.img:match("palm") then
    palmCount = palmCount + 1
    if palmCount == 2 then palmREntry = e; break end
  end
end
check(palmREntry ~= nil, "il palmo destro e' stato disegnato")
if palmREntry then
  local expPalmXR = 100 + a.helmet.shoulder_r[1]
  check(approx(palmREntry.pivot_world[1], expPalmXR, 0.5),
    string.format("palm dx X ~%.2f (got %.2f)", expPalmXR, palmREntry.pivot_world[1]))
end

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All rig FK tests passed.")
end
