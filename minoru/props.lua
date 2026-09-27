-- minoru/props.lua
-- Procedural accessory renderers. Each prop draws centred on (0, 0) inside
-- the caller's current transform, sized for the rig's 1024x1024 anchor
-- space (helmet sphere_radius ~= 307, so a "hat" is ~350-450px wide here).
--
-- These are deliberately primitive -- polygon/rectangle/circle/line -- not
-- hand-drawn PNGs. They exist so the roleplay gear from the I.R. dossier
-- (Napoleon unit, HONHONHON, etc.) is usable *today*, without commissioned
-- art. When real PNG art replaces any of them, swap the accessory from
-- { prop = "napoleon" } to a PNG key in ACCESSORY_FILES; the rig API does
-- not change.
--
-- Contract: every function MUST return without error even when love.graphics
-- is a stub (test harness) and MUST NOT pass NaN/inf to any draw call.

local Props = {}

function Props.napoleon()
  -- Bicorne, worn "en colonne" (the way Napoleon wore it: points fore-aft,
  -- flattened wide). Silhouette: a squat trapezoid with pointed tips.
  love.graphics.setColor(0.13, 0.13, 0.16, 1)
  love.graphics.polygon("fill",
    -220, 0,
    -150, -95,
       0, -125,
     150, -95,
     220, 0,
     150, 40,
    -150, 40)
  -- top fold (gives it depth, otherwise it reads as a flat blob)
  love.graphics.setColor(0.20, 0.20, 0.24, 1)
  love.graphics.polygon("fill",
    -150, -95, 0, -125, 150, -95, 100, -70, 0, -95, -100, -70)
  -- gold trim across the brim
  love.graphics.setColor(0.82, 0.68, 0.28, 1)
  love.graphics.setLineWidth(4)
  love.graphics.line(-220, 0, 220, 0)
  -- cockade (the little round badge)
  love.graphics.setColor(0.85, 0.15, 0.25, 1)
  love.graphics.circle("fill", 0, -20, 16)
  love.graphics.setColor(0.95, 0.95, 0.95, 1)
  love.graphics.circle("fill", 0, -20, 7)
end

function Props.crown()
  -- Five-point crown. Band + triangles + gems.
  love.graphics.setColor(0.82, 0.68, 0.20, 1)
  love.graphics.rectangle("fill", -130, -30, 260, 45, 4, 4)
  love.graphics.polygon("fill", -130, -30, -105, -115, -75, -30)
  love.graphics.polygon("fill",  -80, -30,  -40, -140,   0, -30)
  love.graphics.polygon("fill",    0, -30,   40, -140,  80, -30)
  love.graphics.polygon("fill",   75, -30,  105, -115, 130, -30)
  -- gems
  love.graphics.setColor(0.88, 0.15, 0.45, 1)
  love.graphics.circle("fill", -50, -5, 9)
  love.graphics.circle("fill",   0, -5, 9)
  love.graphics.circle("fill",  50, -5, 9)
end

function Props.antenna()
  -- A bent whip antenna with a glowing tip. Small, subtle.
  love.graphics.setColor(0.42, 0.42, 0.48, 1)
  love.graphics.setLineWidth(6)
  love.graphics.line(0, 0, -12, -70, 8, -140)
  love.graphics.setColor(0.95, 0.30, 0.30, 1)
  love.graphics.circle("fill", 8, -148, 12)
  love.graphics.setColor(0.95, 0.55, 0.55, 0.5)
  love.graphics.circle("fill", 8, -148, 20)
end

function Props.baguette()
  -- A baguette, used by reactHonHonHon(). Rotated rectangle (ellipse would
  -- need love.graphics.ellipse, which the test stubs don't provide).
  love.graphics.push()
  love.graphics.rotate(-0.45)
  love.graphics.setColor(0.86, 0.66, 0.36, 1)
  love.graphics.rectangle("fill", -170, -26, 340, 52, 20, 20)
  -- diagonal score marks (the classic baguette cuts)
  love.graphics.setColor(0.60, 0.42, 0.20, 1)
  love.graphics.setLineWidth(4)
  for i = -4, 4 do
    local x = i * 34
    love.graphics.line(x, -20, x + 14, 20)
  end
  love.graphics.pop()
end

-- List of valid prop names, for validation in Rig:equipAccessory.
Props.names = {
  napoleon = true,
  crown    = true,
  antenna  = true,
  baguette = true,
}

-- Every function in Props that starts with a lowercase letter and isn't
-- "names" is a prop renderer. Used for the runtime existence check.
function Props.exists(name)
  return type(name) == "string" and Props.names[name] == true
end

return Props
