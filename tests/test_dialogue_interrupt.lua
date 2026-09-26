-- tests/test_dialogue_interrupt.lua — lua5.4 tests/test_dialogue_interrupt.lua
-- Regressione: Dialogue:say sovrascriveva un onDone pendente senza mai
-- chiamarlo. Nella demo questo faceva restare rig.talking=true per sempre
-- (SPACE -> reazione -> stopTalking mai invocato).

package.path = package.path .. ";./?.lua"

love = {
  graphics = {
    newFont = function() return {} end,
    getWidth = function() return 800 end, getHeight = function() return 600 end,
    setColor = function() end, setFont = function() end, setLineWidth = function() end,
    rectangle = function() end, line = function() end,
    print = function() end, printf = function() end,
  },
}

local Dialogue = dofile("minoru/dialogue.lua")

local failures = 0
local function check(cond, msg)
  if not cond then failures = failures + 1; print("  FAIL: " .. msg) end
end

-- 1. onDone di una linea completata regolarmente
do
  local d = Dialogue.new({ charsPerSec = 1000 })
  local fired = false
  d:say("A", "ciao", function() fired = true end)
  d:skip()
  d:advance()
  check(fired, "onDone di una linea completata viene chiamato da advance()")
end

-- 2. onDone pendente viene chiamato PRIMA di essere sovrascritto
do
  local d = Dialogue.new({ charsPerSec = 1000 })
  local firstFired = false
  d:say("A", "prima", function() firstFired = true end)
  d:say("B", "seconda", function() end)
  check(firstFired, "il vecchio onDone viene chiamato quando say() lo interrompe")
end

-- 3. onDone interrotto che lancia non propaga l'errore
do
  local d = Dialogue.new({ charsPerSec = 1000 })
  local ok = pcall(function()
    d:say("A", "prima", function() error("callback esplosivo") end)
    d:say("B", "seconda", function() end)
  end)
  check(ok, "un onDone interrotto che lancia non fa crashare say()")
end

-- 4. onDone di una linea chiusa NON viene rieseguito
do
  local d = Dialogue.new({ charsPerSec = 1000 })
  local count = 0
  d:say("A", "ciao", function() count = count + 1 end)
  d:skip()
  d:advance()
  d:say("B", "seconda", function() end)
  check(count == 1, "onDone non viene rieseguito (got " .. count .. ")")
end

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All dialogue interrupt tests passed.")
end
