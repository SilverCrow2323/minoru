-- demo/main.lua — Minoru⁶ showcase app.
-- This is a THIN demo of the library in minoru/ — the integration itself is
-- just Minoru.new() + mo:update(dt) + mo:draw(x,y,scale), see below. If
-- you're looking for how to embed Minoru in YOUR OWN program, this file and
-- minoru/init.lua's header comment are the two things to read.
--
-- Run with `love demo` from the repo root, or `love demo.love` once built.
--
-- Controls:
--   ARROW KEYS   move around (leaves a short mood-colored trail)
--   LSHIFT       hold while moving to dash (longer/brighter trail)
--   SPACE        talk (gestures + visor line react, closes on ENTER)
--   S            sarcastic     H  happy        U  surprised
--   C            confused      E  embarrassed  F  repressed anger (fuming)
--   X            speechless    T  sad          Z  sleepy
--   D            determined    A  angry        V  glitch
--   M            professor act (hat + pointer, mocking-lecture mode)
--   P            processing (thinking)
--   G            push persona.json to GitHub (needs demo/secrets.lua)
--   ENTER        advance / close the dialogue box

local Minoru = require("minoru")

local mo
local rigX, rigY, rigScale = 0, 0, 0.62
local MOVE_SPEED = 220
local DASH_SPEED = 900

function love.load()
  love.graphics.setBackgroundColor(0.03, 0.03, 0.04)

  local ok, githubCfg = pcall(require, "secrets")
  if not ok then githubCfg = nil end

  mo = Minoru.new({
    assetsPath = "minoru/assets/",
    dialogue = { charsPerSec = 40 },
    github = githubCfg,
    -- Fase 3: start high, auto-degrade if FPS drops on low-power ARM.
    quality = "high",
    adaptiveQuality = true,
  })

  rigX = (love.graphics.getWidth() - 1024 * rigScale) / 2
  rigY = (love.graphics.getHeight() - 1024 * rigScale) / 2

  mo:say("Sistemi avviati. Frecce=muoviti  SPAZIO=parla  " ..
    "S/H/U/C/E/F/X/T/Z/D/A/V/M=reazioni  Q=apprensione  W=paradosso  " ..
    "J=comrade  K=lezione  L=serio  F1=profiler  F2=qualita'  G=sync")
end

function love.update(dt)
  local t0 = love.timer.getTime()
  mo:update(dt)
  profStats.updateMs = smooth(profStats.updateMs, (love.timer.getTime() - t0) * 1000)

  local dx, dy = 0, 0
  if love.keyboard.isDown("left") then dx = dx - 1 end
  if love.keyboard.isDown("right") then dx = dx + 1 end
  if love.keyboard.isDown("up") then dy = dy - 1 end
  if love.keyboard.isDown("down") then dy = dy + 1 end
  if dx ~= 0 or dy ~= 0 then
    local len = math.sqrt(dx * dx + dy * dy)
    local speed = love.keyboard.isDown("lshift") and DASH_SPEED or MOVE_SPEED
    rigX = rigX + (dx / len) * speed * dt
    rigY = rigY + (dy / len) * speed * dt
  end
end

-- Fase 3: F1 toggles a small profiler overlay (FPS + ms per section +
-- current quality tier). Numbers come from love.timer; on the RG35XX H
-- this is how you actually decide whether the default tier holds 60 FPS.
local profilerOn = false
local profStats = { updateMs = 0, drawMs = 0 }
local PROFILE_SMOOTH = 0.9

local function smooth(old, new)
  return old * PROFILE_SMOOTH + new * (1 - PROFILE_SMOOTH)
end

function love.draw()
  local t0 = love.timer.getTime()
  mo:draw(rigX, rigY, rigScale)
  local t1 = love.timer.getTime()
  profStats.drawMs = smooth(profStats.drawMs, (t1 - t0) * 1000)

  if profilerOn then
    local font = love.graphics.getFont()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 8, 8, 260, 92, 4, 4)
    love.graphics.setColor(0.1, 0.95, 0.85, 1)
    local q = mo.rig.qualityName or "?"
    local lines = {
      string.format("FPS:      %d", love.timer.getFPS()),
      string.format("update:  %.2f ms", profStats.updateMs),
      string.format("draw:    %.2f ms", profStats.drawMs),
      string.format("quality: %s (N=%d, glow=%d, trail=%d)", q,
        mo.rig.quality.visorN, mo.rig.quality.visorGlow, mo.rig.quality.trailMax),
    }
    for i, l in ipairs(lines) do
      love.graphics.print(l, 14, 12 + (i - 1) * 20)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
end

-- key -> {Minoru reaction method, line of dialogue}
local REACTION_KEYS = {
  s = { "reactSarcastic",   "Oh, fantastico. Un'altra idea brillante." },
  h = { "reactHappy",       "Sì! Esatto, proprio così!" },
  u = { "reactSurprised",   "Whoa— non me l'aspettavo." },
  c = { "reactConfused",    "Aspetta, aspetta... non ho capito." },
  e = { "reactEmbarrassed", "Ehm... si', scusa, hai ragione." },
  f = { "reactFuming",      "...va tutto bene. Tutto benissimo." },
  x = { "reactSpeechless",  "..." },
  t = { "reactSad",         "Giornata pesante..." },
  z = { "reactSleepy",      "Mmh... che c'e'..." },
  d = { "reactDetermined",  "Ok. Ci penso io." },
  a = { "reactAngry",       "ORA BASTA!" },
  v = { "reactGlitch",      "ERR—ORE— sist#ma no%n rispo--nde." },
  m = { "reactMocking",     "Ah, certo. Lascia che te lo spieghi io, con calma, per la millesima volta." },

  -- v1.2.0 — moods canonici dal dossier I.R.
  q = { "reactApprehensive", "Ehm... non e' che mi preoccupo, eh. Solo... cautela tattica. Non guardarmi cosi." },
  w = { "reactParadox",      "ERR0RE DI REALTÀ. IL RINTROMPO SI STA— [rumore di interferenza] —NON DOVREI AVERLO VISTO." },
  -- "Altruismo Selettivo": la maschera cade, per una volta.
  j = { "reactComrade",      "...Sono qui, Pips. Non dico altro." },
  k = { "reactLecture",      "Vediamo se riesco a spiegartelo senza che tu ti perda al secondo concetto. Spoiler: non ci riuscirai." },
  l = { "reactStern",        "Adesso basta scherzare." },
}

function love.keypressed(key)
  if key == "f1" then
    profilerOn = not profilerOn
    return
  end
  if key == "f2" then
    -- cycle quality: high -> medium -> low -> high
    local order = { "high", "medium", "low", "high" }
    local cur = mo.rig.qualityName or "high"
    local nextQ = "high"
    for i, n in ipairs(order) do
      if n == cur and i < #order then nextQ = order[i + 1]; break end
    end
    mo.rig:setQuality(nextQ)
    mo:say("Qualità: " .. nextQ)
    return
  end
  if key == "return" or key == "kpenter" then
    mo:advance()
    return
  end

  local r = REACTION_KEYS[key]
  if r then
    mo[r[1]](mo)
    mo:touch({ mood = mo.rig.mood, kind = "reaction", note = r[2] })
    mo:say(r[2])
    return
  end

  if key == "space" then
    mo:startTalking()
    mo:touch({ mood = "standard", kind = "talk" })
    mo:say("Sto parlando adesso: guarda gesti e visiera reagire.", function() mo:stopTalking() end)
  elseif key == "p" then
    mo:setProcessing(true)
    mo:touch({ mood = "processing", kind = "think" })
    mo:say("Sto elaborando...", function() mo:setProcessing(false) end)
  elseif key == "g" then
    mo:say("Sincronizzo su GitHub...")
    mo:syncPersona(function(ok, err)
      mo:say(ok and "Persona sincronizzata su GitHub." or ("Sync fallita: " .. tostring(err)))
    end)
  end
end
