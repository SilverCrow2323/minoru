-- minoru/init.lua
-- The single entry point for embedding Minoru⁶ in your own LÖVE program.
--
--   local Minoru = require("minoru")
--   local mo = Minoru.new()
--
--   function love.update(dt) mo:update(dt) end
--   function love.draw() mo:draw(240, 200, 0.6) end
--
-- That's the whole integration. Everything rig.lua/dialogue.lua/persona.lua
-- expose (reactHappy, setMood, say, remember, ...) is available directly on
-- the object `Minoru.new()` gives you — see the __index delegation below —
-- so you don't need to reach into mo.rig / mo.dialogue / mo.persona for
-- normal use. They're still there (mo.rig, mo.dialogue, mo.persona, and the
-- Sync module via require("minoru.sync")) for anything this facade doesn't
-- cover.
--
-- opts (all optional):
--   assetsPath        default "minoru/assets/"     — where the rig-kit PNGs live
--   saveFile          default "minoru_persona.json" — love.filesystem save path
--   name              default "Minoru⁶"             — speaker name in dialogue boxes
--   dialogue          table passed straight to Dialogue.new (x,y,w,h,font,charsPerSec)
--   github            {owner=,repo=,token=,path=,branch=} — enables :syncPersona()
--   autoSyncInterval  seconds; if set (and `github` is set), auto-syncs on that cadence

local Rig = require("minoru.rig")
local Dialogue = require("minoru.dialogue")
local Persona = require("minoru.persona")
local Sync = require("minoru.sync")
local json = require("minoru.json")

local Minoru = {}

Minoru.VERSION = "1.0.0-dev"

function Minoru.new(opts)
  opts = opts or {}
  local self = { name = opts.name or "Minoru\xE2\x81\xB6" }

  self.rig = Rig.new(opts.assetsPath)
  self.dialogue = Dialogue.new(opts.dialogue)
  self.persona = Persona.load(opts.saveFile or "minoru_persona.json")
  self.githubCfg = opts.github
  self.autoSyncInterval = opts.autoSyncInterval
  self._syncTimer = 0

  return setmetatable(self, {
    __index = function(t, k)
      local own = Minoru[k]
      if own then return own end
      local rigMethod = Rig[k]
      if rigMethod then
        return function(_, ...) return rigMethod(t.rig, ...) end
      end
      return nil
    end,
  })
end

function Minoru:update(dt)
  self.rig:update(dt)
  self.dialogue:update(dt)
  Sync.poll()
  if self.autoSyncInterval and self.githubCfg then
    self._syncTimer = self._syncTimer + dt
    if self._syncTimer >= self.autoSyncInterval then
      self._syncTimer = 0
      self:syncPersona()
    end
  end
end

function Minoru:draw(x, y, scale)
  self.rig:draw(x, y, scale)
  self.dialogue:draw()
end

-- Convenience wrapper around dialogue:say that fills in Minoru's own name.
function Minoru:say(text, onDone)
  self.dialogue:say(self.name, text, onDone)
end

function Minoru:advance()
  self.dialogue:advance()
end

-- Logs an interaction AND saves immediately — the "remembers every
-- interaction" behavior, in one call instead of two.
function Minoru:touch(event)
  self.persona:touch(event)
  self.persona:save()
end

function Minoru:remember(key, value)
  self.persona:remember(key, value)
  self.persona:save()
end

function Minoru:recall(key)
  return self.persona:recall(key)
end

function Minoru:forget(key)
  self.persona:forget(key)
  self.persona:save()
end

-- Pushes persona.json to GitHub in the background (see minoru/sync.lua) —
-- never blocks your frame loop. callback(ok, err) fires from :update() once
-- the background job finishes. No-ops with an error callback if you never
-- passed `github` to Minoru.new().
function Minoru:syncPersona(callback)
  if not self.githubCfg then
    if callback then callback(false, "no github config set (pass opts.github to Minoru.new)") end
    return
  end
  Sync.pushFileAsync(self.githubCfg, json.encode(self.persona.state),
    "Auto-update persona state", callback)
end

return Minoru
