-- tests/test_init.lua — run with `lua5.4 tests/test_init.lua` from the repo root.
package.path = package.path .. ";./?.lua"

local files = {}
love = {
  graphics = {
    newImage = function(path) return { path = path } end,
    push = function() end, pop = function() end, translate = function() end,
    rotate = function() end, scale = function() end, setColor = function() end,
    draw = function() end, circle = function() end, polygon = function() end,
    rectangle = function() end, stencil = function(fn) if fn then fn() end end,
    setStencilTest = function() end,
    getWidth = function() return 800 end, getHeight = function() return 600 end,
    newFont = function() return {} end,
    setFont = function() end, printf = function() end, print = function() end,
    setLineWidth = function() end,
    line = function() end,
  },
  filesystem = {
    read = function(path)
      if files[path] then return files[path] end
      local f = io.open(path, "r")
      if not f then return nil end
      local c = f:read("*a"); f:close(); return c
    end,
    write = function(path, content) files[path] = content; return true end,
  },
}

local Minoru = dofile("minoru/init.lua")

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("  FAIL: " .. msg)
  end
end

local mo = Minoru.new({ assetsPath = "minoru/assets/", saveFile = "test_persona.json" })

-- delegated rig methods should just work
local ok1, err1 = pcall(function() mo:reactHappy() end)
check(ok1, "delegated reactHappy() should not error: " .. tostring(err1))
check(mo.rig.mood == "happy", "reactHappy actually changed the underlying rig mood")

local ok2 = pcall(function() mo:setGrip("L", 0.5) end)
check(ok2, "delegated setGrip() should not error")
check(mo.rig.poseTarget.gripL == 0.5, "setGrip actually retargets the underlying rig pose (tweens, doesn't snap)")

-- facade's own methods
mo:say("ciao")
check(mo.dialogue.fullText == "ciao", "say() reaches the dialogue box")
check(mo.dialogue.speaker == mo.name, "say() uses Minoru's own name as speaker")

mo:remember("likes", "caffe corretto")
check(mo:recall("likes") == "caffe corretto", "remember/recall round-trip through the facade")

mo:touch({ mood = "happy", kind = "test" })
check(mo.persona.state.interactionCount == 1, "touch() reaches persona and saves")

-- update/draw loop shouldn't error
local ok3, err3 = pcall(function()
  for i = 1, 10 do mo:update(1 / 60); mo:draw(100, 100, 0.5) end
end)
check(ok3, "update/draw loop should not error: " .. tostring(err3))

-- syncPersona without a github config should fail gracefully, not throw
local calledBack, syncOk, syncErr = false, nil, nil
mo:syncPersona(function(ok, err) calledBack, syncOk, syncErr = true, ok, err end)
check(calledBack == true, "syncPersona without github config still calls back")
check(syncOk == false, "syncPersona without github config reports failure")
check(type(syncErr) == "string" and syncErr:match("no github config"),
  "syncPersona without github config reports a clear error (got " .. tostring(syncErr) .. ")")

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All facade (minoru/init.lua) tests passed.")
end
