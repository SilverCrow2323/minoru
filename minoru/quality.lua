-- minoru/quality.lua
-- Quality tiers for the rig/visor renderer. The default ("high") is what
-- every previous version drew. "low"/"medium" trade visual fidelity for
-- fill-rate and draw calls — aimed at low-power ARM handhelds (RG35XX H
-- class) where the visor's ~150 polygons + 150 circles + the 12-ghost
-- 1024×1024 trail can't hold 60 FPS.
--
-- These numbers are HYPOTHESES. Measure on the target with the F1 profiler
-- (in main.lua) before trusting them. Do not treat "60 FPS on my desktop"
-- as evidence — desktops have 10-50x the fill rate.

local Quality = {}

Quality.presets = {
  -- low: handheld-first. Visor at N=20, single glow pass, no motion trail.
  low    = { visorN = 20, visorGlow = 1, trailMax = 0,  trailLife = 0.10, trailSilhouette = true  },

  -- medium: balanced. Trail capped at 6 ghosts, silhouette downscale.
  medium = { visorN = 32, visorGlow = 2, trailMax = 6,  trailLife = 0.14, trailSilhouette = true  },

  -- high: what v1.0.0 drew. Full 48-segment visor, 3 glow passes, 12 ghosts.
  high   = { visorN = 48, visorGlow = 3, trailMax = 12, trailLife = 0.16, trailSilhouette = false },
}

-- Ordered low -> high. Used by adaptive auto-degrade.
Quality.order = { "low", "medium", "high" }

function Quality.get(name)
  return Quality.presets[name] or Quality.presets.high
end

-- Returns the next tier down, or nil if already at "low".
function Quality.degrade(name)
  for i, n in ipairs(Quality.order) do
    if n == name and i > 1 then return Quality.order[i - 1] end
  end
  return nil
end

return Quality
