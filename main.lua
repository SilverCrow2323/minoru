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
  })

  rigX = (love.graphics.getWidth() - 1024 * rigScale) / 2
  rigY = (love.graphics.getHeight() - 1024 * rigScale) / 2

  mo:say("Sistemi avviati. Frecce=muoviti  SPAZIO=parla  " ..
    "S/H/U/C/E/F/X/T/Z/D/A/V=reazioni  M=professore  G=sync")
end

function love.update(dt)
  mo:update(dt)

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

function love.draw()
  mo:draw(rigX, rigY, rigScale)
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
}

function love.keypressed(key)
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
