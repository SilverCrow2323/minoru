-- minoru/visor.lua
-- The mood line is drawn live, every frame, instead of swapping between a
-- handful of pre-rendered PNG frames. That gets us: truly continuous
-- audio-amplitude talk animation (not just 3 snapped frames), a smooth
-- cross-dissolve between moods instead of a hard cut, a live "thinking"
-- dot-pulse loop, and glitch/tremble effects that are actually random each
-- frame instead of a fixed baked pattern.
--
-- helmet.png still ships with an EMPTY visor (as designed) — this module
-- draws entirely inside that empty glass circle, clipped with a stencil so
-- nothing can bleed outside it even during a glitch/tremble spike.
--
-- v1.1.0-dev: N (segment count) and glowPasses are now per-call, driven by
-- the quality tier (see minoru/quality.lua). A small cache holds the shape
-- for the moods whose geometry is time-independent (sad, surprised, sleepy,
-- speechless, determined, and standard at rest) so we don't recompute the
-- same 48 floats every frame for a static line.

local Visor = {}

-- Private RNG for glitch effects — deliberately NOT math.random/randomseed,
-- so Minoru never perturbs the host program's own global random state
-- (important for a library meant to be embedded in someone else's game).
local privateRng = (love.math and love.math.newRandomGenerator) and love.math.newRandomGenerator(0) or nil
local function rnd(a, b)
  if privateRng then
    if a == nil then return privateRng:random() end
    if b == nil then return privateRng:random(a) end
    return privateRng:random(a, b)
  end
  if a == nil then return math.random() end
  if b == nil then return math.random(a) end
  return math.random(a, b)
end
local function reseed(s)
  if privateRng then privateRng:setSeed(s) end
end

local DEFAULT_N = 48

-- XS cache: the -0.82..0.82 sample positions for a given N. Built once per N.
local XS_CACHE = {}
local function getXS(n)
  local xs = XS_CACHE[n]
  if xs then return xs end
  xs = {}
  for i = 1, n do xs[i] = -0.82 + (i - 1) / (n - 1) * 1.64 end
  XS_CACHE[n] = xs
  return xs
end

local COLOR = {
  standard    = { 0x4C/255, 0xD9/255, 0x7A/255 },
  sarcastic   = { 0xF2/255, 0x52/255, 0x52/255 },
  processing  = { 0xA9/255, 0x4F/255, 0xE8/255 },
  sad         = { 0x52/255, 0x99/255, 0xE8/255 },
  angry       = { 0xB8/255, 0x1F/255, 0x1F/255 },
  fuming      = { 0x8F/255, 0x1A/255, 0x1A/255 },
  perplexed   = { 0xF2/255, 0xC9/255, 0x4C/255 },
  happy       = { 0x5C/255, 0xFF/255, 0x9C/255 },
  surprised   = { 0xE8/255, 0xFA/255, 0xFF/255 },
  embarrassed = { 0xF2/255, 0x8F/255, 0xC2/255 },
  sleepy      = { 0x7E/255, 0x9C/255, 0x98/255 },
  determined  = { 0x8F/255, 0xE8/255, 0xFF/255 },
  speechless  = { 0x9A/255, 0x9E/255, 0xA2/255 },
  glitch      = { 0xA9/255, 0x4F/255, 0xE8/255 },
  -- Canon (dossier "Codice Colore della Visiera"):
  --   Blu = Apprensione. Rara, Minoru non ammette di preoccuparsi.
  apprehensive = { 0x4A/255, 0x7A/255, 0xB8/255 },
  --   Viola = [Sconosciuto] / Rintrompo puro. La realtà si sta rompendo.
  paradox      = { 0xC4/255, 0x3F/255, 0xFF/255 },
}
Visor.COLOR = COLOR

local function falloff(x, cutoff)
  local ax = math.abs(x)
  if ax < cutoff * 0.7 then return 1
  elseif ax > cutoff then return 0
  else return (cutoff - ax) / (cutoff * 0.3) end
end

-- raw shape computer, always runs the full loop
local function computeShapeRaw(mood, t, opts, n, xs)
  opts = opts or {}
  local ys, widths = {}, {}
  local amp = opts.amp or 0

  for i = 1, n do
    local x = xs[i]
    local y, w

    if mood == "standard" then
      local env = 1 - math.abs(x / 0.82) ^ 2.2
      if amp <= 0.02 then
        y = 0
      else
        y = amp * 0.34 * math.sin(x * 10 + t * 14) * env
      end
      w = 0.10 + 0.10 * env
    elseif mood == "sarcastic" then
      y = -0.34 * (x / 0.82) ^ 2 + 0.10
      w = 0.075
    elseif mood == "sad" then
      y = 0.42
      w = 0.045 * falloff(x, 0.6)
    elseif mood == "angry" then
      y = 0.42 * math.sin(x * 30 + t * 25) * (0.4 + 0.6 * math.abs(math.sin(x * 6 + t * 3)))
      w = 0.07
    elseif mood == "fuming" then
      y = 0.15 * math.sin(x * 30 + t * 20) * (0.5 + 0.5 * math.abs(math.sin(x * 5)))
      w = 0.06
    elseif mood == "perplexed" then
      y = 0.32 * math.sin(x * (1.5 * math.pi / 0.82) + t * 0.6)
      w = 0.075
    elseif mood == "happy" then
      local env = 1 - (x / 0.82) ^ 2
      y = -0.30 * math.abs(math.sin(x * 7 + t * 3)) * env
      w = 0.06 + 0.05 * env
    elseif mood == "surprised" then
      y = -0.58 * math.exp(-26 * x * x)
      w = 0.06
    elseif mood == "embarrassed" then
      y = 0.10 * math.sin(x * 40 + t * 30) + 0.04 * math.sin(x * 17 + t * 11 + 0.5)
      w = 0.05
    elseif mood == "sleepy" then
      y = 0.30 + 0.05 * math.sin(x * 4 + t * 0.3)
      w = 0.05 * falloff(x, 0.55)
    elseif mood == "determined" then
      local env = 1 - math.abs(x / 0.82) ^ 1.5
      y = 0
      w = 0.14 * env + 0.05
    elseif mood == "speechless" then
      y = 0
      w = 0.05 * falloff(x, 0.35)
    elseif mood == "glitch" then
      y = 0.22 * math.sin(x * 9 + t * 4) + 0.06 * math.sin(x * 23 + t * 9 + 1.0)
      w = 0.07
    elseif mood == "apprehensive" then
      -- Canon: "la linea si abbassa e diventa sottile, quasi un sussurro
      -- luminoso". Piu' sottile di sad, piu' corta in estensione.
      y = 0.28 + 0.02 * math.sin(t * 0.8)
      w = 0.035 * falloff(x, 0.45)
    elseif mood == "paradox" then
      -- Canon: paradosso / Rintrompo puro. La forma flickera in modo
      -- quantizzato (12 scatti/secondo) e produce spike vicino al centro.
      local tick = math.floor(t * 12)
      local jit  = math.sin(x * 11 + tick * 2.3)
      local spk  = math.sin(x * 47 + tick * 5.7)
      if math.abs(x) < 0.15 then
        y = spk * 0.20
      else
        y = jit * 0.08 + spk * 0.05
      end
      w = 0.06 * (0.6 + 0.4 * math.sin(t * 25 + x * 8))
    else
      y, w = 0, 0.08
    end

    ys[i] = y
    widths[i] = w
  end
  return ys, widths
end

-- which moods have t-independent geometry (skip recompute)
local T_INDEPENDENT = {
  sad = true, surprised = true, sleepy = true,
  speechless = true, determined = true,
}

-- cache: [mood][n] = { ys, widths }. Only used for T_INDEPENDENT moods.
local SHAPE_CACHE = {}

local function getShape(mood, t, opts, n, xs)
  local amp = opts and opts.amp or 0
  local cacheable = T_INDEPENDENT[mood] or (mood == "standard" and amp <= 0.02)
  if cacheable then
    local byN = SHAPE_CACHE[mood]
    if not byN then byN = {}; SHAPE_CACHE[mood] = byN end
    local c = byN[n]
    if not c then
      local ys, widths = computeShapeRaw(mood, 0, opts, n, xs)
      c = { ys = ys, widths = widths }
      byN[n] = c
    end
    return c.ys, c.widths
  end
  return computeShapeRaw(mood, t, opts, n, xs)
end

local function strokePath(cx, cy, r, ys, widths, color, alpha, xs, n)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
  local px, py, pw
  for i = 1, n do
    local x = cx + xs[i] * r
    local y = cy + ys[i] * r
    local w = widths[i] * r
    if i > 1 then
      local dx, dy = x - px, y - py
      local len = math.sqrt(dx * dx + dy * dy)
      if len > 0.0001 then
        local nx, ny = -dy / len, dx / len
        love.graphics.polygon("fill",
          px + nx * pw / 2, py + ny * pw / 2,
          x + nx * w / 2, y + ny * w / 2,
          x - nx * w / 2, y - ny * w / 2,
          px - nx * pw / 2, py - ny * pw / 2)
      end
      love.graphics.circle("fill", px, py, pw / 2)
    end
    px, py, pw = x, y, w
  end
  love.graphics.circle("fill", px, py, pw / 2)
end

local function drawLineMood(mood, cx, cy, r, t, opts, alphaMul, n, xs, glowPasses)
  alphaMul = alphaMul or 1
  glowPasses = glowPasses or 3
  if mood == "standard" and (opts.amp or 0) <= 0.02 then
    -- idle "breathing": brightness only, never position
    alphaMul = alphaMul * (0.85 + 0.15 * math.sin(t * 1.3))
  end
  local color = COLOR[mood] or { 1, 1, 1 }
  local ys, widths = getShape(mood, t, opts, n, xs)

  -- glow: a couple of wider, fainter passes behind the crisp core,
  -- count controlled by the quality tier
  if glowPasses >= 2 then
    local gw = {}
    for i = 1, n do gw[i] = widths[i] * 2.6 end
    strokePath(cx, cy, r, ys, gw, color, 0.16 * alphaMul, xs, n)
  end
  if glowPasses >= 3 then
    local gw = {}
    for i = 1, n do gw[i] = widths[i] * 1.7 end
    strokePath(cx, cy, r, ys, gw, color, 0.20 * alphaMul, xs, n)
  end

  local bright = {
    math.min(1, color[1] * 1.25 + 0.12),
    math.min(1, color[2] * 1.25 + 0.12),
    math.min(1, color[3] * 1.25 + 0.12),
  }
  strokePath(cx, cy, r, ys, widths, bright, alphaMul, xs, n)

  if mood == "sarcastic" and opts.glitchSeed then
    reseed(opts.glitchSeed)
    for _ = 1, 6 do
      if rnd() < 0.5 then
        local gx = cx + (rnd() * 1.7 - 0.85) * r
        local gy = cy + (rnd() * 1.7 - 0.85) * r
        love.graphics.setColor(color[1], color[2], color[3], alphaMul * rnd(60, 180) / 255)
        love.graphics.rectangle("fill", gx, gy, r * (0.02 + rnd() * 0.05), r * (0.01 + rnd() * 0.02))
      end
    end
  end

  if mood == "glitch" then
    local ghostCol = { color[1], color[2], color[3] }
    local ysUp, ysDn = {}, {}
    for i = 1, n do ysUp[i] = ys[i] - 0.09; ysDn[i] = ys[i] + 0.09 end
    strokePath(cx, cy, r, ysUp, widths, ghostCol, 0.28 * alphaMul, xs, n)
    strokePath(cx, cy, r, ysDn, widths, ghostCol, 0.28 * alphaMul, xs, n)
    for _ = 1, 4 do
      local yy = cy + (rnd() * 1.4 - 0.7) * r
      local xx0 = cx + (rnd() * 1.0 - 0.8) * r
      local ww = r * (0.2 + rnd() * 0.35)
      love.graphics.setColor(1, 1, 1, alphaMul * 0.25)
      love.graphics.rectangle("fill", xx0, yy, ww, r * 0.012)
    end
  end
end

local function drawProcessingDots(cx, cy, r, t, alphaMul)
  alphaMul = alphaMul or 1
  local color = COLOR.processing
  local offsets = { -0.34, 0, 0.34 }
  for i, ox in ipairs(offsets) do
    local phase = (t * 0.8 - (i - 1) * 0.30) % 1
    local b = 0.5 + 0.5 * math.sin(phase * 2 * math.pi - math.pi / 2)
    local dotR = r * (0.075 + 0.03 * b)
    love.graphics.setColor(color[1], color[2], color[3], alphaMul * 0.35 * b)
    love.graphics.circle("fill", cx + ox * r, cy, dotR * 2.2)
    love.graphics.setColor(color[1], color[2], color[3], alphaMul * (0.55 + 0.45 * b))
    love.graphics.circle("fill", cx + ox * r, cy, dotR)
  end
end

-- state: { mood=, prevMood=, blend=0..1, t=, opts=, processing=bool,
--          prevProcessing=bool, currentAlpha=, N=, glowPasses= }
function Visor.draw(cx, cy, r, state)
  love.graphics.stencil(function()
    love.graphics.circle("fill", cx, cy, r)
  end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)

  local n = state.N or DEFAULT_N
  local xs = getXS(n)
  local glow = state.glowPasses or 3

  local blend = state.blend or 1
  local ca = state.currentAlpha or 1
  if state.prevMood and blend < 1 then
    if state.prevProcessing then
      drawProcessingDots(cx, cy, r, state.t, (1 - blend) * ca)
    else
      drawLineMood(state.prevMood, cx, cy, r, state.t, state.prevOpts or {}, (1 - blend) * ca, n, xs, glow)
    end
  end

  if state.processing then
    drawProcessingDots(cx, cy, r, state.t, blend * ca)
  else
    drawLineMood(state.mood, cx, cy, r, state.t, state.opts or {}, blend * ca, n, xs, glow)
  end

  love.graphics.setStencilTest()
  love.graphics.setColor(1, 1, 1, 1)
end

return Visor
