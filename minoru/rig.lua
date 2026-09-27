-- minoru/rig.lua
-- Minoru⁶ has no legs — he floats. Rig: helmet (head/body) + 2 arms, each
-- ending in a palm with 5 fingers of 3 phalanges each. Built as real
-- forward-kinematics chains via love.graphics.push/translate/rotate, using
-- the pivots in anchors.json — verified in test_rig.lua.
--
-- The visor line itself is NOT a swapped PNG anymore — minoru/visor.lua draws
-- it live every frame (see that file for why). This file just tracks
-- *which* mood is active, a cross-dissolve blend when it changes, and the
-- continuous talk amplitude / processing flag that visor.lua reads.
--
-- Also carries: expression icons (sweat drop, anger mark, ...), procedural
-- talk gestures, named poses + a reaction library (reactFuming,
-- reactSpeechless, ...), always-on idle float bob, and a short mood-tinted
-- motion trail when he moves.

local json = require("minoru.json")
local Visor = require("minoru.visor")
local Quality = require("minoru.quality")
local Props = require("minoru.props")

local Rig = {}
Rig.__index = Rig

-- Private RNG for idle fidgets and pose-variant picking — same reasoning as
-- visor.lua: never touch the host program's own math.random/randomseed.
local privateRng = (love.math and love.math.newRandomGenerator) and love.math.newRandomGenerator(1) or nil
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

local ICON_FILES = {
  sweat_drop        = "icons/sweat_drop.png",
  anger_mark        = "icons/anger_mark.png",
  question_mark     = "icons/question_mark.png",
  exclamation_mark  = "icons/exclamation_mark.png",
  sparkle           = "icons/sparkle.png",
}

local ACCESSORY_FILES = {
  prof_hat       = "accessories/prof_hat.png",
  pointer_stick  = "accessories/pointer_stick.png",
}

local LIMB_NAMES = { "upper_arm", "forearm", "palm", "finger_proximal", "finger_middle", "finger_distal" }

local function moodTrailColor(mood, processing)
  if processing then return Visor.COLOR.processing end
  return Visor.COLOR[mood] or Visor.COLOR.standard
end

-- tuning
local IDLE_FREQ = 1.1
local IDLE_AMP = 9
local TRAIL_MIN_DIST = 3
local TRAIL_MAX_ALPHA = 0.55
-- TRAIL_LIFETIME and TRAIL_MAX_ENTRIES are now per-instance, from quality
local MOOD_TRANSITION_TIME = 0.15 -- cross-dissolve duration when the mood changes

-- named poses (radians). 0 = arm hanging straight down.
local POSE = {
  relaxed      = { shoulderL = 0,     elbowL = 0,     shoulderR = 0,     elbowR = 0 },
  slumped      = { shoulderL = -0.18, elbowL = 0.55,  shoulderR = 0.18,  elbowR = -0.55 },
  akimbo       = { shoulderL = -0.55, elbowL = 1.9,   shoulderR = 0,     elbowR = 0 },
  flinchBack   = { shoulderL = -0.35, elbowL = -0.25, shoulderR = 0.35,  elbowR = 0.25 },
  thinking     = { shoulderL = 0.65,  elbowL = 2.2,   shoulderR = 0,     elbowR = 0 },
  tenseFists   = { shoulderL = -0.12, elbowL = 1.35,  shoulderR = 0.12,  elbowR = -1.35 },
  ready        = { shoulderL = -0.30, elbowL = 0.9,   shoulderR = 0.30,  elbowR = -0.9 },
  teaching     = { shoulderL = -0.20, elbowL = 0.4,   shoulderR = -0.65, elbowR = -1.7 },
  crossedArms  = { shoulderL = -0.75, elbowL = 2.5,   shoulderR = 0.75,  elbowR = -2.5 },
  shrug        = { shoulderL = -0.9,  elbowL = -0.5,  shoulderR = 0.9,   elbowR = 0.5 },
  wave         = { shoulderL = 0,     elbowL = 0,     shoulderR = -1.4,  elbowR = 2.6 },
  pointForward = { shoulderL = 0.15,  elbowL = 0.15,  shoulderR = -1.1,  elbowR = -0.15 },
  armsWide     = { shoulderL = -1.5,  elbowL = -0.15, shoulderR = 1.5,   elbowR = 0.15 },
  handsOnHips  = { shoulderL = -0.55, elbowL = 1.9,   shoulderR = 0.55,  elbowR = -1.9 },
  -- Canon (dossier, "Altruismo Selettivo"): quando la situazione e' seria
  -- Minoru smette di punzecchiare e si comporta con rispetto ed empatia.
  -- Posa aperta, non teatrale, una mano leggermente offerta.
  comrade      = { shoulderL = -0.20, elbowL = 0.35,  shoulderR = -0.35, elbowR = 0.55 },
  -- "Mi rimetto sull'attenti, ma non sono incazzato": spalle basse,
  -- gomiti controllati, niente tremolio. La linea del visore fa il resto.
  stern        = { shoulderL = -0.15, elbowL = 0.25,  shoulderR = 0.15,  elbowR = -0.25 },
}

-- Easing curves for pose transitions (t: 0..1 -> 0..1). Picked per-reaction
-- to match its "force": sharp+overshoot for a startled flinch, slow and
-- heavy for sadness, and so on — see react*() below.
local EASE = {
  linear = function(t) return t end,
  easeOutQuad = function(t) return 1 - (1 - t) ^ 2 end,
  easeOutCubic = function(t) return 1 - (1 - t) ^ 3 end,
  easeInOutSine = function(t) return -(math.cos(math.pi * t) - 1) / 2 end,
  easeOutBack = function(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
  end,
  easeOutElastic = function(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1
  end,
}

-- opts (optional): { quality = "low"|"medium"|"high", adaptiveQuality = bool }
-- Backward-compatible: a string second arg is treated as opts.quality.
function Rig.new(basePath, opts)
  basePath = basePath or "minoru/assets/"
  if type(opts) == "string" then opts = { quality = opts } end
  opts = opts or {}
  local self = setmetatable({}, Rig)
  self.qualityName = opts.quality or "high"
  self.quality = Quality.get(self.qualityName)
  self.adaptiveQuality = opts.adaptiveQuality and true or false
  self._fpsWindow = {}

  local raw = love.filesystem.read(basePath .. "anchors.json")
  assert(raw, "rig: could not read anchors.json at " .. basePath)
  self.anchors = json.decode(raw)

  self.helmet = love.graphics.newImage(basePath .. "helmet.png")

  -- Pre-rendered, downscaled silhouette used for motion-trail ghosts on
  -- low/medium quality. On a handheld the full 1024x1024 helmet drawn 12x
  -- per frame eats an enormous amount of fill rate for what is, visually,
  -- a fading smear. 128x128 is plenty. Skipped if love.graphics.newCanvas
  -- is missing (test harness).
  self.trailSilhouette = nil
  self.trailSilhouetteScale = 1
  if self.quality.trailSilhouette
     and love.graphics.newCanvas and love.graphics.setCanvas then
    local hw = (self.helmet.getWidth and self.helmet:getWidth()) or 1024
    local hh = (self.helmet.getHeight and self.helmet:getHeight()) or 1024
    local size = 128
    local ok, canvas = pcall(love.graphics.newCanvas, size, size)
    if ok and canvas then
      local prev = love.graphics.getCanvas and love.graphics.getCanvas()
      love.graphics.setCanvas(canvas)
      if love.graphics.clear then love.graphics.clear(0, 0, 0, 0) end
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(self.helmet, 0, 0, 0, size / hw, size / hh)
      love.graphics.setCanvas(prev)
      love.graphics.setColor(1, 1, 1, 1)
      self.trailSilhouette = canvas
      self.trailSilhouetteScale = hw / size
    end
  end

  self.icons = {}
  for name, relPath in pairs(ICON_FILES) do
    self.icons[name] = love.graphics.newImage(basePath .. relPath)
  end
  self.activeIcon = nil
  self.iconTimeLeft = 0

  self.accessoryImages = {}
  for name, relPath in pairs(ACCESSORY_FILES) do
    self.accessoryImages[name] = love.graphics.newImage(basePath .. relPath)
  end
  self.accessories = { head = nil, handL = nil, handR = nil }

  self.limbs = {}
  for _, name in ipairs(LIMB_NAMES) do
    self.limbs[name] = love.graphics.newImage(basePath .. "limbs/" .. name .. ".png")
  end

  -- visor/mood state
  self.mood = "standard"
  self.processing = false
  self.prevMood, self.prevProcessing = nil, nil
  self.blend = 1 -- 1 = fully on self.mood, no transition in progress
  self.visorT = 0

  self.talking = false
  self.autoTalk = false
  self.talkAmp = 0
  self.talkPhase = 0
  self.talkIntensity = 0.6 -- 0..1, scales talk-gesture/amplitude liveliness

  self.speechlessFlicker = false
  self.idleT = 0
  self.trembleAmp = 0

  -- Idle blink (canon: la visiera e' un "oscilloscopio emotivo"; un
  -- robot che non lampeggia mai sembra morto). Timer casuale 3-6s,
  -- durata blink 0.14s. Solo quando e' fermo, standard, non parla.
  self.blinkTimer = 3 + rnd() * 3
  self.blinkPhase = 0

  self.trail = {}
  self.lastX, self.lastY, self.lastScale = nil, nil, nil

  self.pose = {
    shoulderL = 0, elbowL = 0,
    shoulderR = 0, elbowR = 0,
    gripL = 0.15, gripR = 0.15,
  }
  -- pose tweening: self.pose holds the CURRENT animated values (what's
  -- actually drawn); setPose/setNamedPose retarget poseTarget and let
  -- update(dt) ease self.pose toward it over poseDuration seconds instead
  -- of snapping instantly.
  self.poseFrom = {}
  self.poseTarget = {}
  for k, v in pairs(self.pose) do self.poseFrom[k] = v; self.poseTarget[k] = v end
  self.poseT = 1 -- 1 = settled, no transition in progress
  self.poseDuration = 0.35
  self.poseEase = "easeOutCubic"

  -- idle fidgeting, so a resting Minoru is never perfectly frozen
  self.idleFidgetTimer = 2 + rnd() * 3
  return self
end

-- ---------------- low-level primitives ----------------

local function beginTransition(self)
  self.prevMood, self.prevProcessing = self.mood, self.processing
  self.blend = 0
end

function Rig:setMood(name)
  assert(Visor.COLOR[name] ~= nil, "rig: unknown mood '" .. tostring(name) .. "'")
  if name ~= self.mood or self.processing then beginTransition(self) end
  self.mood = name
  self.processing = false
  self.talking = false
  self.autoTalk = false
  self.talkAmp = 0
  self.speechlessFlicker = false
end

function Rig:setProcessing(on)
  on = on and true or false
  if on ~= self.processing then beginTransition(self) end
  self.processing = on
  if on then
    self.talking = false
    self.autoTalk = false
    self.talkAmp = 0
  end
end

function Rig:startTalking() self.talking = true; self.processing = false; self.autoTalk = true end
function Rig:stopTalking() self.talking = false; self.talkAmp = 0 end

-- amplitude in [0,1] from your own audio/voice analysis, called every frame
-- while talking for real lip-sync-by-amplitude instead of the built-in
-- auto-talk fallback pattern.
function Rig:setTalkAmplitude(amp)
  self.talkAmp = math.max(0, math.min(1, amp or 0))
  self.autoTalk = false
end

-- 0..1: how big/fast his talk gestures AND the auto-talk fallback waveform
-- are. Tie this to how emphatic the current line is.
function Rig:setTalkIntensity(x)
  self.talkIntensity = math.max(0, math.min(1, x or 0))
end

-- Retargets the pose smoothly instead of snapping. `partial` is the same
-- shape as before ({shoulderL=, elbowL=, ...}); `opts` (optional):
--   duration  seconds for the transition (default 0.35, or whatever was
--             last used — each react*() below sets one matching its "force")
--   ease      one of the EASE keys above (default "easeOutCubic")
-- Re-triggering mid-transition redirects smoothly from wherever the pose
-- currently IS, not from the old target — no snapping back first.
function Rig:setPose(partial, opts)
  opts = opts or {}
  for k, v in pairs(partial) do
    assert(self.pose[k] ~= nil, "rig: unknown pose key '" .. k .. "'")
  end
  for k, v in pairs(self.pose) do self.poseFrom[k] = v end
  for k, v in pairs(partial) do self.poseTarget[k] = v end
  self.poseDuration = math.max(0.001, opts.duration or self.poseDuration)
  self.poseEase = opts.ease or self.poseEase
  self.poseT = 0
end

function Rig:setNamedPose(name, opts)
  assert(POSE[name], "rig: unknown named pose '" .. tostring(name) .. "'")
  self:setPose(POSE[name], opts)
end

function Rig:setGrip(side, amount, opts)
  self:setPose({ ["grip" .. side] = math.max(0, math.min(1, amount or 0)) }, opts)
end

function Rig:setTremble(amount)
  self.trembleAmp = amount or 0
end

function Rig:showIcon(name, duration)
  assert(self.icons[name] ~= nil, "rig: unknown icon '" .. tostring(name) .. "'")
  self.activeIcon = name
  self.iconTimeLeft = duration or 1.5
end

function Rig:hideIcon() self.activeIcon = nil end

-- slot: "head" | "handL" | "handR".
-- name: one of
--   * a string key in ACCESSORY_FILES -> PNG-based accessory
--   * a table { prop = "napoleon" } -> procedural (minoru/props.lua)
--   * nil -> unequip
function Rig:equipAccessory(slot, name)
  assert(slot == "head" or slot == "handL" or slot == "handR",
    "rig: unknown accessory slot '" .. tostring(slot) .. "'")
  if name == nil then
    self.accessories[slot] = nil
    return
  end
  if type(name) == "table" and name.prop then
    assert(Props.exists(name.prop),
      "rig: unknown procedural prop '" .. tostring(name.prop) .. "'")
    self.accessories[slot] = { prop = name.prop }
    return
  end
  assert(self.accessoryImages[name], "rig: unknown accessory '" .. tostring(name) .. "'")
  self.accessories[slot] = name
end

function Rig:unequipAccessory(slot)
  self.accessories[slot] = nil
end

-- ---------------- reaction library ----------------
-- Each reaction's transition duration/ease is picked to match its
-- emotional "force" — a startled flinch snaps fast with a little recoil,
-- sadness eases in slowly and heavily, sarcasm has a light bouncy snap.
-- Several also pick randomly among a couple of equally-valid poses so the
-- same reaction doesn't always look identical.

local function pick(...)
  local opts = { ... }
  return opts[rnd(1, #opts)]
end

function Rig:reactIdle()
  self:setMood("standard")
  self:setNamedPose("relaxed", { duration = 0.5, ease = "easeInOutSine" })
  self:setTremble(0); self:hideIcon(); self:dropAllAccessories()
end

function Rig:reactSarcastic()
  self:setMood("sarcastic")
  self:setNamedPose(pick("akimbo", "crossedArms", "handsOnHips"), { duration = 0.28, ease = "easeOutBack" })
  self:setTremble(0)
end

function Rig:reactHappy()
  self:setMood("happy")
  self:setNamedPose(pick("ready", "wave", "armsWide"), { duration = 0.30, ease = "easeOutBack" })
  self:showIcon("sparkle", 1.2)
end

function Rig:reactSurprised()
  self:setMood("surprised")
  self:setNamedPose("flinchBack", { duration = 0.10, ease = "easeOutBack" })
  self:showIcon("exclamation_mark", 1.0)
end

function Rig:reactConfused()
  self:setMood("perplexed")
  self:setNamedPose(pick("thinking", "shrug"), { duration = 0.35, ease = "easeOutQuad" })
  self:showIcon("question_mark", 1.6)
end

function Rig:reactEmbarrassed()
  self:setMood("embarrassed")
  self:setNamedPose("slumped", { duration = 0.45, ease = "easeInOutSine" })
  self:showIcon("sweat_drop", 1.6)
end

function Rig:reactSad()
  self:setMood("sad")
  self:setNamedPose("slumped", { duration = 0.8, ease = "easeInOutSine" })
  self:hideIcon()
end

function Rig:reactSleepy()
  self:setMood("sleepy")
  self:setNamedPose("slumped", { duration = 1.0, ease = "easeInOutSine" })
  self:hideIcon()
end

function Rig:reactDetermined()
  self:setMood("determined")
  self:setNamedPose(pick("ready", "pointForward"), { duration = 0.22, ease = "easeOutBack" })
  self:hideIcon()
end

function Rig:reactAngry()
  self:setMood("angry")
  self:setNamedPose("tenseFists", { duration = 0.15, ease = "easeOutBack" })
  self:setGrip("L", 0.9, { duration = 0.15, ease = "easeOutBack" })
  self:setGrip("R", 0.9, { duration = 0.15, ease = "easeOutBack" })
  self:setTremble(0); self:hideIcon()
end

-- "pugni stretti con tremolio" — repressed anger: snaps in fast and tight,
-- but controlled (no bouncy overshoot like the full outburst above) —
-- the trembling itself carries the rest of the tension.
function Rig:reactFuming()
  self:setMood("fuming")
  self:setNamedPose("tenseFists", { duration = 0.18, ease = "easeOutCubic" })
  self:setGrip("L", 1.0, { duration = 0.18, ease = "easeOutCubic" })
  self:setGrip("R", 1.0, { duration = 0.18, ease = "easeOutCubic" })
  self:setTremble(0.045)
  self:showIcon("anger_mark", 2.0)
end

-- "braccia abbattute con goccia di sudore" — speechless: a slow collapse.
function Rig:reactSpeechless(duration)
  self:setMood("speechless")
  self:setNamedPose("slumped", { duration = 0.6, ease = "easeInOutSine" })
  self:setTremble(0)
  self:setGrip("L", 0.1, { duration = 0.6 }); self:setGrip("R", 0.1, { duration = 0.6 })
  self.speechlessFlicker = true
  self:showIcon("sweat_drop", duration or 2.2)
end

function Rig:reactGlitch() self:setMood("glitch"); self:setTremble(0.02) end

-- Canon: "Estremamente rara (Minoru non ammette di preoccuparsi)".
-- Reazione sottile, quasi invisibile: nessuna icona, tremolio quasi nullo,
-- linea blu bassa. Se la vedi, e' successo qualcosa di serio.
function Rig:reactApprehensive()
  self:setMood("apprehensive")
  self:setNamedPose("slumped", { duration = 0.7, ease = "easeInOutSine" })
  self:setTremble(0.008)
  self:hideIcon()
end

-- Canon: "il colore del paradosso o del Rintrompo puro. Quando appare,
-- significa che la realtà sta per rompersi... o Minoru ha visto qualcosa
-- che non doveva". Glitch aggressivo, ma con un innesco diverso da reactGlitch.
function Rig:reactParadox()
  self:setMood("paradox")
  self:setNamedPose("tenseFists", { duration = 0.12, ease = "easeOutCubic" })
  self:setGrip("L", 0.7, { duration = 0.12 }); self:setGrip("R", 0.7, { duration = 0.12 })
  self:setTremble(0.03)
  self:showIcon("question_mark", 1.8)
end

-- Canon ("Altruismo Selettivo"): la reazione onesta, senza sarcasmo. Non
-- c'e' una posa teatrale, non c'e' un'icona, non c'e' tremolio. Il mood
-- resta "standard" — la sincerita' di Minoru non e' uno stato emotivo
-- speciale, e' la sua versione normale quando smette la maschera.
function Rig:reactComrade()
  self:setMood("standard")
  self:setNamedPose("comrade", { duration = 0.6, ease = "easeInOutSine" })
  self:setTremble(0)
  self:setGrip("L", 0.15, { duration = 0.6 }); self:setGrip("R", 0.15, { duration = 0.6 })
  self:hideIcon(); self:dropAllAccessories()
end

-- Canon: la modalita' "didattica" senza il cappello. Il professor act
-- (reactMocking) e' la parodia; reactLecture e' la spiegazione vera, quando
-- Minoru decide di essere utile invece di essere stronzo.
function Rig:reactLecture()
  self:setMood("determined")
  self:setNamedPose("teaching", { duration = 0.4, ease = "easeOutCubic" })
  self:setTremble(0)
  self:hideIcon(); self:dropAllAccessories()
end

-- "Adesso basta scherzare": posa composta, mood determined, braccia
-- incrociate. Non e' rabbia (reactAngry) ne' fumo represso (reactFuming):
-- e' il momento in cui Minoru smette di fare il pagliaccio.
function Rig:reactStern()
  self:setMood("determined")
  self:setNamedPose("crossedArms", { duration = 0.35, ease = "easeOutCubic" })
  self:setTremble(0)
  self:hideIcon()
end

-- Canon (dossier, "NAPOLEON UNIT / Playful, grandose comedic unit"): the
-- full bit -- bicorne, arms crossed, chin up, dead serious about it.
function Rig:reactNapoleon()
  self:setMood("determined")
  self:setNamedPose("crossedArms", { duration = 0.30, ease = "easeOutBack" })
  self:setTremble(0)
  self:equipAccessory("head", { prop = "napoleon" })
  self:equipAccessory("handL", nil)
  self:equipAccessory("handR", nil)
  self:showIcon("sparkle", 1.2)
end

-- Canon (dossier, "HONHONHON" under ROLEPLAY GEAR): the French-chef bit.
-- Professor hat + baguette in the right hand, teaching pose, sarcastic mood.
-- Distinct from reactMocking (pointer stick, hat, no baguette).
function Rig:reactHonHonHon()
  self:setMood("sarcastic")
  self:setNamedPose("teaching", { duration = 0.30, ease = "easeOutBack" })
  self:setTremble(0)
  self:equipAccessory("head", "prof_hat")
  self:equipAccessory("handR", { prop = "baguette" })
  self:equipAccessory("handL", nil)
  self:showIcon("question_mark", 1.4)
end

-- "sfodera dei gadget per scimmiottare gli umani" — puts on the professor
-- act (hat + pointer) to lecture/mock condescendingly, holograms implied.
function Rig:reactMocking()
  self:setMood("sarcastic")
  self:setNamedPose("teaching", { duration = 0.35, ease = "easeOutBack" })
  self:equipAccessory("head", "prof_hat")
  self:equipAccessory("handR", "pointer_stick")
end

function Rig:dropAllAccessories()
  self:unequipAccessory("head"); self:unequipAccessory("handL"); self:unequipAccessory("handR")
end

-- ---------------- per-frame update ----------------

-- Manual quality switch. Returns the new tier name.
function Rig:setQuality(name)
  local q = Quality.get(name)
  self.quality = q
  self.qualityName = name
  return name
end

-- Adaptive auto-degrade: track a rolling window of FPS. If the average
-- stays below 48 for ~3 seconds, drop one tier. Never climbs back up
-- (hysteresis: better to sit at "low" than oscillate). Requires
-- love.timer; no-op in the test harness.
local ADAPT_FPS_THRESHOLD = 48
local ADAPT_WINDOW_SECONDS = 3

function Rig:_tickAdaptiveQuality(dt)
  if not self.adaptiveQuality then return end
  if not (love.timer and love.timer.getFPS) then return end
  self._fpsWindow[#self._fpsWindow + 1] = { t = dt, fps = love.timer.getFPS() }
  local total = 0
  for _, e in ipairs(self._fpsWindow) do total = total + e.t end
  -- drop old samples beyond the window
  while total > ADAPT_WINDOW_SECONDS and #self._fpsWindow > 1 do
    total = total - self._fpsWindow[1].t
    table.remove(self._fpsWindow, 1)
  end
  if total < ADAPT_WINDOW_SECONDS * 0.9 then return end
  local sum, n = 0, 0
  for _, e in ipairs(self._fpsWindow) do sum = sum + e.fps; n = n + 1 end
  local avg = sum / n
  if avg < ADAPT_FPS_THRESHOLD then
    local lower = Quality.degrade(self.qualityName)
    if lower then
      self:setQuality(lower)
      self._fpsWindow = {}
    end
  end
end

function Rig:update(dt)
  self:_tickAdaptiveQuality(dt)
  self.idleT = self.idleT + dt
  self.visorT = self.visorT + dt

  if self.talking and self.autoTalk then
    self.talkPhase = self.talkPhase + dt * (3 + 5 * self.talkIntensity)
    self.talkAmp = 0.35 + 0.65 * math.abs(math.sin(self.talkPhase))
  end

  if self.blend < 1 then
    self.blend = math.min(1, self.blend + dt / MOOD_TRANSITION_TIME)
  end

  if self.poseT < 1 then
    self.poseT = math.min(1, self.poseT + dt / self.poseDuration)
    local ease = EASE[self.poseEase] or EASE.easeOutCubic
    local e = ease(self.poseT)
    for k, targetV in pairs(self.poseTarget) do
      local fromV = self.poseFrom[k] or targetV
      self.pose[k] = fromV + (targetV - fromV) * e
    end
  end

  -- idle fidgeting: only while genuinely at rest (settled pose, standard
  -- mood, not talking/processing) so it never fights a real reaction
  if self.poseT >= 1 and self.mood == "standard" and not self.talking and not self.processing then
    self.idleFidgetTimer = self.idleFidgetTimer - dt
    if self.idleFidgetTimer <= 0 then
      self.idleFidgetTimer = 3 + rnd() * 4
      local jitter = 0.10
      self:setPose({
        shoulderL = (rnd() * 2 - 1) * jitter, elbowL = (rnd() * 2 - 1) * jitter,
        shoulderR = (rnd() * 2 - 1) * jitter, elbowR = (rnd() * 2 - 1) * jitter,
      }, { duration = 0.9 + rnd() * 0.6, ease = "easeInOutSine" })
    end
  end

  -- idle blink: azzera occasionalmente l'alpha del visore per un istante.
  -- Non e' un ammiccamento vero (non abbiamo palpebre), e' il pattern che
  -- rende un oscilloscopio "vivo" quando e' a riposo.
  if self.blinkPhase > 0 then
    self.blinkPhase = math.max(0, self.blinkPhase - dt)
  elseif self.mood == "standard" and not self.talking and not self.processing
         and self.poseT >= 1 then
    self.blinkTimer = self.blinkTimer - dt
    if self.blinkTimer <= 0 then
      self.blinkTimer = 3 + rnd() * 3
      self.blinkPhase = 0.14
    end
  end

  if self.activeIcon then
    self.iconTimeLeft = self.iconTimeLeft - dt
    if self.iconTimeLeft <= 0 then self.activeIcon = nil end
  end
  for i = #self.trail, 1, -1 do
    self.trail[i].life = self.trail[i].life - dt
    if self.trail[i].life <= 0 then table.remove(self.trail, i) end
  end
end

-- ---------------- drawing ----------------

local function drawArm(self, shoulderAttach, shoulderAngle, elbowAngle, grip, flip, accessoryName)
  local sx = flip and -1 or 1
  local aU, aF, aP = self.anchors.upper_arm, self.anchors.forearm, self.anchors.palm
  local aFp, aFm, aFd = self.anchors.finger_proximal, self.anchors.finger_middle, self.anchors.finger_distal
  local lenU = aU.pivot_bottom[2] - aU.pivot_top[2]
  local lenF = aF.pivot_bottom[2] - aF.pivot_top[2]
  local lenFp = aFp.pivot_bottom[2] - aFp.pivot_top[2]
  local lenFm = aFm.pivot_bottom[2] - aFm.pivot_top[2]

  love.graphics.push()
  love.graphics.translate(shoulderAttach[1], shoulderAttach[2])
  love.graphics.scale(sx, 1)
  love.graphics.rotate(shoulderAngle)
  love.graphics.draw(self.limbs.upper_arm, 0, 0, 0, 1, 1, aU.pivot_top[1], aU.pivot_top[2])
  love.graphics.translate(0, lenU)
  love.graphics.rotate(elbowAngle)
  love.graphics.draw(self.limbs.forearm, 0, 0, 0, 1, 1, aF.pivot_top[1], aF.pivot_top[2])
  love.graphics.translate(0, lenF)
  love.graphics.draw(self.limbs.palm, 0, 0, 0, 1, 1, aP.pivot_wrist[1], aP.pivot_wrist[2])

  for _, fb in ipairs(aP.finger_bases) do
    love.graphics.push()
    love.graphics.translate(fb.pos[1] - aP.pivot_wrist[1], fb.pos[2] - aP.pivot_wrist[2])
    love.graphics.rotate(math.rad(fb.angle_deg) + grip.p)
    love.graphics.draw(self.limbs.finger_proximal, 0, 0, 0, 1, 1, aFp.pivot_top[1], aFp.pivot_top[2])
    love.graphics.translate(0, lenFp)
    love.graphics.rotate(grip.m)
    love.graphics.draw(self.limbs.finger_middle, 0, 0, 0, 1, 1, aFm.pivot_top[1], aFm.pivot_top[2])
    love.graphics.translate(0, lenFm)
    love.graphics.rotate(grip.d)
    love.graphics.draw(self.limbs.finger_distal, 0, 0, 0, 1, 1, aFd.pivot_top[1], aFd.pivot_top[2])
    love.graphics.pop()
  end

  if accessoryName then
    if type(accessoryName) == "table" and accessoryName.prop then
      -- procedural prop, drawn centred at the palm/grip origin.
      -- prop draws around (0,0); the transform is already at the grip point.
      love.graphics.push()
      love.graphics.translate(0, 38)  -- same offset as the PNG pointer grip
      local fn = Props[accessoryName.prop]
      if fn then fn() end
      love.graphics.pop()
      love.graphics.setColor(1, 1, 1, 1)
    else
      local accImg = self.accessoryImages[accessoryName]
      local accAnc = self.anchors[accessoryName]
      if accImg and accAnc then
        local off = accAnc.grip_offset_from_wrist or { 0, 0 }
        love.graphics.draw(accImg, off[1], off[2], 0, 1, 1, accAnc.pivot_grip[1], accAnc.pivot_grip[2])
      end
    end
  end

  love.graphics.pop()
end

-- full=true draws helmet + live visor line + icon + both arms in real
-- color; full=false draws ONLY the helmet silhouette (cheap), tinted
-- whatever color the caller already set — used for the motion-trail ghosts.
function Rig:_drawAt(x, y, scale, full, noBob)
  love.graphics.push()
  love.graphics.translate(x, y)
  -- breathing: pulse di scala molto sottile, 0.8% (canon: il casco e'
  -- una sfera; un respiro umano e' ~1% di variazione sul torace, che
  -- su una sfera si traduce in ~0.8% di raggio).
  local breath = 1 + math.sin(self.idleT * 0.7) * 0.008
  love.graphics.scale(scale * breath, scale * breath)
  if not noBob then
    love.graphics.translate(0, math.sin(self.idleT * IDLE_FREQ) * IDLE_AMP)
  end

  if full then love.graphics.setColor(1, 1, 1, 1) end
  if (not full) and self.trailSilhouette then
    local s = self.trailSilhouetteScale
    love.graphics.draw(self.trailSilhouette, 0, 0, 0, s, s)
  else
    love.graphics.draw(self.helmet, 0, 0)
  end

  if full then
    local h = self.anchors.helmet
    local currentAlpha = 1
    if self.speechlessFlicker and self.mood == "speechless" and self.blend >= 1 then
      currentAlpha = 0.35 + 0.5 * math.abs(math.sin(self.idleT * 9))
    end
    if self.blinkPhase > 0 then
      -- 0.14s di "chiusura": alpha che crolla e risale
      local k = self.blinkPhase / 0.14
      currentAlpha = currentAlpha * (0.06 + 0.94 * (1 - k))
    end
    Visor.draw(h.visor_center[1], h.visor_center[2], h.visor_radius * 0.90, {
      mood = self.mood, processing = self.processing,
      prevMood = self.prevMood, prevProcessing = self.prevProcessing,
      blend = self.blend, t = self.visorT, currentAlpha = currentAlpha,
      opts = { amp = (self.talking and self.talkAmp) or 0, glitchSeed = math.floor(self.idleT * 12) },
      N = self.quality.visorN,
      glowPasses = self.quality.visorGlow,
    })
    love.graphics.setColor(1, 1, 1, 1)

    if self.activeIcon then
      local ia = self.anchors.icon_anchor or { 700, 340 }
      love.graphics.draw(self.icons[self.activeIcon], ia[1], ia[2])
    end

    if self.accessories.head then
      local acc = self.accessories.head
      if type(acc) == "table" and acc.prop then
        -- procedural head prop: anchored at the crown of the helmet.
        -- head_top is (512, 180) in the 1024x1024 canvas.
        love.graphics.push()
        love.graphics.translate(h.head_top[1], h.head_top[2] - 20)
        local fn = Props[acc.prop]
        if fn then fn() end
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
      else
        local accImg = self.accessoryImages[acc]
        local accAnc = self.anchors[acc]
        if accImg and accAnc then
          love.graphics.draw(accImg, h.head_top[1], h.head_top[2], 0, 1, 1,
            accAnc.pivot_attach[1], accAnc.pivot_attach[2])
        end
      end
    end

    local shakeL, shakeR = 0, 0
    if self.trembleAmp > 0 then
      shakeL = math.sin(self.idleT * 45) * self.trembleAmp
      shakeR = math.sin(self.idleT * 45 + 1.7) * self.trembleAmp
    end
    local gestureL, gestureR = 0, 0
    local elbowGestureL, elbowGestureR = 0, 0
    if self.talking then
      local amp = 0.18 * self.talkIntensity
      gestureL = math.sin(self.talkPhase * 0.9) * amp
      gestureR = math.sin(self.talkPhase * 0.9 + math.pi * 0.6) * amp
      -- secondary motion: il gomito segue la spalla con un piccolo ritardo
      -- di fase (principio classico di animazione: le estremita' inseguono
      -- il corpo, non si muovono insieme).
      local amp2 = 0.13 * self.talkIntensity
      elbowGestureL = math.sin(self.talkPhase * 0.9 - 0.45) * amp2
      elbowGestureR = math.sin(self.talkPhase * 0.9 + math.pi * 0.6 - 0.45) * amp2
    end

    local gL = { p = math.rad(55) * self.pose.gripL, m = math.rad(70) * self.pose.gripL, d = math.rad(55) * self.pose.gripL }
    local gR = { p = math.rad(55) * self.pose.gripR, m = math.rad(70) * self.pose.gripR, d = math.rad(55) * self.pose.gripR }
    drawArm(self, h.shoulder_l, self.pose.shoulderL + shakeL + gestureL, self.pose.elbowL + shakeL + elbowGestureL, gL, false, self.accessories.handL)
    drawArm(self, h.shoulder_r, self.pose.shoulderR + shakeR + gestureR, self.pose.elbowR + shakeR + elbowGestureR, gR, true, self.accessories.handR)
  end

  love.graphics.pop()
end

function Rig:draw(x, y, scale)
  scale = scale or 1

  if self.lastX then
    local dx, dy = x - self.lastX, y - self.lastY
    if self.quality.trailMax > 0
       and (dx * dx + dy * dy) > (TRAIL_MIN_DIST * TRAIL_MIN_DIST) then
      local life = self.quality.trailLife
      table.insert(self.trail, {
        x = self.lastX, y = self.lastY, scale = self.lastScale or scale,
        color = moodTrailColor(self.mood, self.processing),
        life = life, maxLife = life,
      })
      while #self.trail > self.quality.trailMax do table.remove(self.trail, 1) end
    end
  end
  self.lastX, self.lastY, self.lastScale = x, y, scale

  for _, t in ipairs(self.trail) do
    local a = (t.life / t.maxLife) * TRAIL_MAX_ALPHA
    love.graphics.setColor(t.color[1], t.color[2], t.color[3], a)
    self:_drawAt(t.x, t.y, t.scale, false, true)
  end
  love.graphics.setColor(1, 1, 1, 1)

  self:_drawAt(x, y, scale, true)
end

return Rig
