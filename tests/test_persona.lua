-- tests/test_persona.lua — run with `lua5.4 tests/test_persona.lua` from the repo root.
package.path = package.path .. ";./?.lua"

local files = {}
love = {
  filesystem = {
    read = function(path) return files[path] end,
    write = function(path, content) files[path] = content; return true end,
  },
}

local Persona = dofile("minoru/persona.lua")

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("  FAIL: " .. msg)
  end
end

local p = Persona.load("persona_test.json")
check(p.state.interactionCount == 0, "fresh state starts at 0 interactions")

p:touch({ mood = "happy", kind = "greet", note = "ciao" })
p:touch({ mood = "standard", kind = "talk" })
check(p.state.interactionCount == 2, "touch increments interactionCount")
check(p.state.mood == "standard", "touch updates mood")
check(#p.state.log == 2, "touch appends to the log")

p:remember("likes", "caffe corretto")
p:remember("likes", "caffe corretto doppio") -- overwrite, not duplicate
check(p:recall("likes") == "caffe corretto doppio", "remember overwrites in place")
check(p:recall("nope") == nil, "recall of unknown key is nil")

p:save()
local p2 = Persona.load("persona_test.json")
check(p2:recall("likes") == "caffe corretto doppio", "facts survive save/load round-trip")
check(p2.state.interactionCount == 2, "counters survive save/load round-trip")

p2:forget("likes")
check(p2:recall("likes") == nil, "forget removes the fact")

-- rolling log cap
for i = 1, 250 do p2:touch({ kind = "spam" }) end
check(#p2.state.log <= 200, "log is capped (got " .. #p2.state.log .. ")")

-- backward compatibility: a save from before `facts` existed
files["old.json"] = '{"name":"Minoru","interactionCount":3,"log":[]}'
local p3 = Persona.load("old.json")
check(type(p3.state.facts) == "table", "loading a pre-facts save doesn't error, upgrades in place")
p3:remember("x", "y")
check(p3:recall("x") == "y", "remember works after upgrading an old save")

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All persona tests passed.")
end
