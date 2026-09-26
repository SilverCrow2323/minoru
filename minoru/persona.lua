-- minoru/persona.lua
-- Local persistent "persona" state for Minoru⁶ — the file that gets updated
-- on every interaction, per the brief. Stored via love.filesystem, so it
-- lands in the correct save directory on both desktop and muOS without any
-- platform-specific path handling on your part.

local json = require("minoru.json")

local Persona = {}
Persona.__index = Persona

local MAX_LOG_ENTRIES = 200

local function defaultState()
  return {
    name = "Minoru\xE2\x81\xB6", -- "Minoru⁶"
    mood = "standard",
    interactionCount = 0,
    firstSeen = os.time(),
    lastInteraction = os.time(),
    log = {},
    facts = {}, -- growing knowledge base about the person using it: key -> {value=, updatedAt=}
  }
end

function Persona.load(saveFile)
  saveFile = saveFile or "persona.json"
  local raw = love.filesystem.read(saveFile)
  local state
  if raw then
    local ok, decoded = pcall(json.decode, raw)
    state = (ok and type(decoded) == "table") and decoded or defaultState()
  else
    state = defaultState()
  end
  state.facts = state.facts or {} -- safe upgrade for saves made before this field existed
  return setmetatable({ state = state, saveFile = saveFile }, Persona)
end

-- event = { mood=<string>, kind=<string>, note=<string> }
-- Call this on every interaction, as requested — it bumps counters, updates
-- the mood, and appends a rolling log entry (capped so the file can't grow
-- without bound).
function Persona:touch(event)
  event = event or {}
  self.state.interactionCount = (self.state.interactionCount or 0) + 1
  self.state.lastInteraction = os.time()
  if event.mood then self.state.mood = event.mood end

  local log = self.state.log or {}
  log[#log + 1] = { t = os.time(), kind = event.kind or "interaction", note = event.note or "" }
  if #log > MAX_LOG_ENTRIES then
    local trimmed = {}
    for i = (#log - MAX_LOG_ENTRIES + 1), #log do
      trimmed[#trimmed + 1] = log[i]
    end
    log = trimmed
  end
  self.state.log = log
end

function Persona:save()
  return love.filesystem.write(self.saveFile, json.encode(self.state))
end

-- The growing "knowledge base" side of the persona, separate from the
-- rolling interaction log: durable facts about the person using it
-- ("piace il caffe'", "lavora di notte", ...), keyed however you like.
-- Overwrites on repeat use, so it's safe to call every time you learn the
-- same thing again — it just refreshes updatedAt.
function Persona:remember(key, value)
  self.state.facts[key] = { value = value, updatedAt = os.time() }
end

function Persona:recall(key)
  local f = self.state.facts[key]
  return f and f.value or nil
end

function Persona:forget(key)
  self.state.facts[key] = nil
end

-- All remembered facts as a plain key->value table (drops the timestamps),
-- handy for building a prompt/context blob if you hook Minoru up to an LLM.
function Persona:allFacts()
  local out = {}
  for k, f in pairs(self.state.facts) do out[k] = f.value end
  return out
end

return Persona
