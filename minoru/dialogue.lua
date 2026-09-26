-- minoru/dialogue.lua
-- A small typewriter-style dialogue box, styled after the SPDW Factory Lab
-- HUD look (dark panel, neon cyan border, magenta speaker name, corner ticks).

local utf8 = require("utf8")

local Dialogue = {}
Dialogue.__index = Dialogue

-- byte-safe prefix of the first nChars UTF-8 characters of s (never cuts a
-- multi-byte character in half — that's what was crashing love.graphics.print
-- with "UTF-8 decoding error: Not enough space" on text like "Minoru⁶" or
-- any accented Italian character, since #s counts BYTES, not characters).
local function utf8Sub(s, nChars)
  if nChars <= 0 then return "" end
  local byteEnd = utf8.offset(s, nChars + 1) or (#s + 1)
  return s:sub(1, byteEnd - 1)
end

function Dialogue.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Dialogue)
  self._explicit = {
    x = opts.x ~= nil, y = opts.y ~= nil,
    w = opts.w ~= nil, h = opts.h ~= nil,
  }
  self.autoLayout = opts.autoLayout ~= false
  self.x = opts.x or 40
  self.y = opts.y or (love.graphics.getHeight() - 160)
  self.w = opts.w or (love.graphics.getWidth() - 80)
  self.h = opts.h or 120
  self.font = opts.font or love.graphics.newFont(16)
  self.speaker = ""
  self.fullText = ""
  self.fullLen = 0
  self.shown = 0
  self.charsPerSec = opts.charsPerSec or 38
  self.timer = 0
  self.visible = false
  self.onDone = nil
  return self
end

function Dialogue:say(speaker, text, onDone)
  -- Se una linea precedente era ancora a schermo con un onDone in sospeso,
  -- lo chiamiamo ADESSO prima di sovrascriverlo. Senza questo, un
  -- startTalking() interrotto da una reazione lasciava rig.talking=true
  -- per sempre (il callback stopTalking non arrivava mai).
  if self.visible and self.onDone then
    local prev = self.onDone
    self.onDone = nil
    pcall(prev)
  end
  self.speaker = speaker or ""
  self.fullText = text or ""
  self.fullLen = utf8.len(self.fullText) or #self.fullText
  self.shown = 0
  self.timer = 0
  self.visible = true
  self.onDone = onDone
end

function Dialogue:isTyping()
  return self.shown < self.fullLen
end

function Dialogue:skip()
  self.shown = self.fullLen
end

-- call this from love.keypressed / a confirm button: skips the typewriter
-- effect on the first press, closes the box (and fires onDone) on the next.
function Dialogue:advance()
  if not self.visible then return end
  if self:isTyping() then
    self:skip()
  else
    self.visible = false
    local cb = self.onDone
    self.onDone = nil
    if cb then cb() end
  end
end

function Dialogue:update(dt)
  if not self.visible or not self:isTyping() then return end
  self.timer = self.timer + dt
  local want = math.floor(self.timer * self.charsPerSec)
  self.shown = math.min(self.fullLen, want)
end

-- ricalcola x/y/w/h in base alla finestra se non sono stati passati
-- esplicitamente (autoLayout, attivo di default)
function Dialogue:resize()
  if not self._explicit.x then self.x = 40 end
  if not self._explicit.y then self.y = love.graphics.getHeight() - 160 end
  if not self._explicit.w then self.w = love.graphics.getWidth() - 80 end
  if not self._explicit.h then self.h = 120 end
end

function Dialogue:draw()
  if self.autoLayout then self:resize() end
  if not self.visible then return end
  local x, y, w, h = self.x, self.y, self.w, self.h

  love.graphics.setColor(0.04, 0.05, 0.06, 0.92)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(0.10, 0.95, 0.85, 0.9) -- neon cyan
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)

  local tick = 10
  love.graphics.line(x, y + tick, x, y, x + tick, y)
  love.graphics.line(x + w - tick, y, x + w, y, x + w, y + tick)
  love.graphics.line(x, y + h - tick, x, y + h, x + tick, y + h)
  love.graphics.line(x + w - tick, y + h, x + w, y + h, x + w, y + h - tick)

  love.graphics.setFont(self.font)
  if self.speaker ~= "" then
    love.graphics.setColor(1, 0.3, 0.85, 1) -- neon magenta
    love.graphics.print(self.speaker, x + 16, y + 10)
  end
  love.graphics.setColor(0.9, 0.95, 0.95, 1)
  love.graphics.printf(utf8Sub(self.fullText, self.shown), x + 16, y + 36, w - 32)

  if not self:isTyping() then
    love.graphics.setColor(0.10, 0.95, 0.85, 0.8)
    love.graphics.print(">", x + w - 24, y + h - 26)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Dialogue
