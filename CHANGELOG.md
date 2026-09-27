## v1.2.0 — canonical moods, animation polish, i18n policy (2026-09-27)
Aligns the library with the I.R. Minoru⁶ dossier.

### Canonical moods (visor)
- Added `apprehensive` (canon: blue, rare, "Minoru non ammette di
  preoccuparsi"): line drops low and goes thin, slow breathing.
- Added `paradox` (canon: violet, "il colore del paradosso o del
  Rintrompo puro"): time-quantized flicker at 12 Hz, center spikes.

### New reactions
- `reactApprehensive()` — subtle, almost invisible, no icon.
- `reactParadox()` — glitch-adjacent but distinct: clenched grip, question
  mark, violet line.
- `reactComrade()` — the honest-friend mode from "Altruismo Selettivo".
  No sarcasm, no icon, no theatrics. Mood stays standard on purpose: his
  sincerity isn't a special state, it's what's underneath the mask.
- `reactLecture()` — didactic mode, teaching pose *without* the professor
  hat (reactMocking is the parody; this is the real explanation).
- `reactStern()` — "adesso basta scherzare". Crossed arms, determined
  mood, no tremble. Not anger, not fuming.

### Animation polish (rig)
- **Breathing**: subtle whole-rig scale pulse, ±0.8%, 0.7 Hz. A robot
  with a spherical casing that never "breathes" reads as dead.
- **Idle blink**: every 3–6s while genuinely at rest (standard mood,
  settled pose, not talking, not processing), the visor alpha briefly
  drops to 6% for 0.14s. Not an eye-blink (no eyelids) — the idle pulse
  of a live oscilloscope.
- **Gesture secondary motion**: during talking, elbows now lag the
  shoulders by a small phase offset (~0.45 rad). Classic animation
  principle (extremities follow the body, they don't move in lockstep).

### Language policy
- Added `docs/I18N.md`: code/comments/docs in English (library is
  embedded by third parties); demo dialogue stays Italian (Minoru's
  canonical voice, not a localization oversight).

### Demo
- New keybindings: `Q` apprehension, `W` paradox, `J` comrade,
  `K` lecture, `L` stern — each with a canonical-voice line.

### Not in this release (deferred)
- `v1.3.0`: procedural accessories (Napoleon hat, HONHONHON emote,
  role-play gear from the dossier).
- `v1.4.0`: real *Units* (Desk Lamp, Wrist Node, Hologram, Mecha) — a
  rendering-mode refactor, needs art + a mode system.

## v1.1.0-dev — Fase 3: performance groundwork (2026-09-26)
Performance profiling on real hardware is still pending — these are the
tools and safe optimizations, not the measurements. The hypotheses below
are honest guesses; do not trust them until you run the F1 profiler on
the target.

- Added `minoru/quality.lua` with `low`/`medium`/`high` presets: visor
  segment count (20/32/48), glow passes (1/2/3), trail budget (0/6/12).
  `Minoru.new({quality = "low"})` opts in; default stays `high`.
- Added pre-rendered 128x128 helmet silhouette for trail ghosts on
  low/medium — cuts trail fill rate by ~64x vs the full 1024x1024 sprite.
  This is the single most likely bottleneck on Mali-G31-class hardware.
- Added visor shape cache for time-independent moods (sad, surprised,
  sleepy, speechless, determined, standard-at-rest): 48 floats per frame
  no longer recomputed for static lines.
- Added adaptive auto-degrade (`adaptiveQuality = true`): drops one tier
  if the rolling 3s FPS average stays under 48. Hysteresis: never climbs
  back up.
- Added F1 profiler overlay in the demo (FPS, update ms, draw ms, current
  quality) and F2 to cycle quality tiers manually.
- Bumped `Minoru.VERSION` to `1.1.0-dev`.

**Not measured yet.** The numbers in quality.lua are derived from first
principles (fill rate, segment count), not from `love.timer` on a
RG35XX H. Until that happens, treat v1.1.0-dev as a hypothesis under
test, not a validated release.

## v1.0.0 — 2026-09-26

First stable release. Stabilization (Fase 0), test hardening (Fase 1) and sync security (Fase 4) are complete. Performance profiling on handheld hardware (Fase 3) is explicitly deferred to v1.1 — see README's "Status" section for what that means.

### Fase 4 — sync security
- Token no longer appears on the curl command line (was visible in
  `ps` / /proc/<pid>/cmdline): written to a 0600 temp curl config file
  and passed via `-K file`, removed even on error
- Added `--max-time 30 --retry 2` to all curl calls (no more hangs on
  a dead network)
- `runCapture` now returns the exit code; a curl network failure is
  reported explicitly ("curl exit 28: ...") instead of being silently
  misread as "no sha" or "unknown curl/API error"
- `tests/test_sync.lua` rewritten: 8 cases including a security
  regression test that fails if the token ever reappears on the
  command line, and a network-error test with a mocked exit 28

### Fase 1 — test hardening
- Added tests/test_dialogue_interrupt.lua (regression onDone overwrite)
- Added tests/test_sync.lua (io.popen mocked, no network/token)
- Added .luacheckrc + luacheck step in CI
- Added docs/API.md with the honest public API
- Added the missing `tests/test_tween.lua` referenced by v0.7's README/CI
- Fixed: expression icons drew at canvas (0,0) instead of near the helmet —
  new `icon_anchor` in anchors.json
- Fixed: visor ignored the `currentAlpha` the rig passes for the
  speechless-flicker effect, so the flicker never actually showed
- Fixed: setMood/setProcessing left a stale talkAmp behind, so the visor
  kept tremoring as if still talking after a reaction interrupted a line
- Fixed: Dialogue:say silently overwrote a pending onDone, which could
  leave `rig.talking == true` forever (SPACE -> reaction left the rig
  stuck talking). Previous onDone now fires on interrupt.
- Fixed: the pointer_stick accessory drew at the wrist pivot; it now
  offsets to the palm centre via `grip_offset_from_wrist`
- Fixed: motion-trail ghosts re-bobbed with the live idle phase each
  frame, so the trail shimmered instead of being a frozen after-image
- Fixed: Dialogue box now re-layouts on window resize (autoLayout, on by
  default; explicit x/y/w/h still respected)
- test_rig.lua now actually asserts FK positions against anchors.json
  instead of printing "compare by eye"
- Added `Minoru.VERSION` and a top-level `VERSION` file

# Changelog

## v0.7 — animated pose transitions, idle fidgeting, more variety
- Pose/mood changes no longer snap instantly — `setPose`/`setNamedPose`/
  `setGrip` now tween smoothly over a configurable duration + easing curve
  instead of jumping straight to the target
- Each `react*()` picks a duration/easing matched to its emotional "force":
  `reactSurprised` snaps fast with a little recoil (`easeOutBack`, 0.10s),
  `reactSleepy`/`reactSad` ease in slow and heavy (`easeInOutSine`, 0.8-1.0s),
  `reactFuming` snaps in tight and controlled (no bounce, unlike the full
  `reactAngry` outburst which does bounce)
- Re-triggering a reaction mid-transition redirects smoothly from wherever
  the pose currently *is* — no snap-back-then-forward
- 6 new named poses for variety (crossedArms, shrug, wave, pointForward,
  armsWide, handsOnHips); several reactions now pick randomly among 2-3
  equally-valid poses so repeats don't look identical
- Idle fidgeting: while genuinely at rest, Minoru now occasionally (every
  ~3-7s) drifts into a small randomized pose and eases back — never
  perfectly frozen
- Added `tests/test_tween.lua`: no-snap behavior, exact target convergence,
  mid-transition redirect, every easing curve checked for NaN/inf, and a
  couple of force/duration spot-checks

## v0.6 — UTF-8 crash fix
- Fixed a real crash: the dialogue typewriter effect sliced `fullText` by
  *byte* count (`:sub(1, shown)`), which could cut a multi-byte UTF-8
  character in half — any accented Italian letter, or the "⁶" in Minoru's
  own name — throwing `UTF-8 decoding error: Not enough space` from
  `love.graphics.printf`. Now advances by UTF-8 character count via Lua's
  `utf8` library. Added `tests/test_dialogue.lua`, which steps the
  typewriter through accent-heavy text frame-by-frame and fails on any
  invalid/truncated UTF-8 reaching printf — confirmed it reproduces the
  original crash before the fix and passes clean after.

## v0.5 — library restructure (current)
- Split into `minoru/` (portable library) + root `main.lua`/`conf.lua` (demo)
- Added `minoru/init.lua`: a single facade (`Minoru.new()`) for embedding in
  any other LÖVE program — delegates to rig/dialogue/persona automatically
- Async GitHub sync via `love.thread` (`Sync.pushFileAsync` + `Sync.poll`) —
  the old synchronous `Sync.pushFile` no longer risks freezing the host's
  frame loop on a slow network call
- Fixed: visor glitch effects were reseeding the *global* `math.random`
  every frame, which could interfere with a host program's own randomness —
  now uses a private `love.math.RandomGenerator`
- Fixed a real bug: `(x/0.82)^2.2` is NaN in Lua for negative `x` (fractional
  power of a negative base) — this silently dropped the left half of the
  "standard" visor line, which looked like the whole line had drifted right.
  Added `tests/test_visor.lua` to catch this class of bug going forward
- Fixed: the idle "breathing" wobble had a per-x phase, making the line look
  tilted rather than centered at rest — idle life is now a brightness pulse
  only, position never moves
- Added a small test suite (`tests/`): json round-trip, persona save/load/
  remember, rig forward-kinematics, visor NaN/inf sanity, facade delegation
- Added `.gitignore`, `LICENSE` (MIT, code only), `NOTICE.md` (art rights),
  minimal GitHub Actions CI (syntax-check + test suite on push)

## v0.4 — persona knowledge base, accessories, character-lore alignment
- `persona:remember/recall/forget/allFacts` — a durable fact store, not just
  a rolling interaction log; old saves upgrade in place
- Equippable accessory system (`equipAccessory`/`unequipAccessory`): a
  professor hat + pointer stick to start, extensible to more props later
- `reactMocking()` — hat + pointer + a lecturing pose
- Confirmed the visor color/mood mapping against the character's own lore
  (green=standard, red=sarcastic, dark red=anger, blue=rare apprehension,
  violet=paradox/unknown) — no changes needed, it already matched

## v0.3 — procedural visor line
- The mood line is drawn live every frame (`minoru/visor.lua`) instead of
  swapped PNG frames: truly continuous talk-amplitude animation, a smooth
  cross-dissolve between moods, a live pulsing "processing" dot loop, and
  glitch/tremble effects that are genuinely random per frame
- Expanded from 5 to 13 named moods (added fuming, perplexed, happy,
  surprised, embarrassed, sleepy, determined, speechless, glitch)
- 5 "anime accent" icons (sweat drop, anger mark, question/exclamation
  mark, sparkle) shown briefly near the helmet
- Procedural talk gestures, named poses, a `react*()` convenience library,
  always-on idle float, short mood-tinted motion trail when moving

## v0.2 — legless rig with articulated hands
- Removed the legs entirely — Minoru floats, arms + hands only
- Hands rebuilt as palm + 5 fingers, each finger a 3-phalanx chain
  (proximal/middle/distal), all forward-kinematics, verified against
  anchors.json in `tests/test_rig.lua`
- Joints and finger phalanges recolored darker than the body, per spec

## v0.1 — first rig-kit + LÖVE prototype
- Full-body pose pack (helmet+arms+legs baked per-pose) and later a proper
  bone-rig kit (helmet + separate limb pieces + anchors.json)
- First LÖVE2D project: rig renderer, dialogue box, local persona file,
  synchronous GitHub sync
