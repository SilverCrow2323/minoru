# Minoru⁶

> **v1.0.0 — stable.** Feature-frozen. Bugfixes only from here.
>
> Developed on Linux desktop, also targets handhelds running muOS
> (tested on RG35XX H). Performance profiling on the handheld is
> **deferred to v1.1** — the current visor renderer is not tuned for
> low-power ARM. See "Known limitations" below.


A floating, sarcastic robot companion — LÖVE2D rig + procedural visor
animation + dialogue box + a persona that remembers things about whoever
it's talking to. Built to be dropped into *any* other LÖVE program as a
digital-assistant character, not just run standalone.

```lua
local Minoru = require("minoru")
local mo = Minoru.new()

function love.update(dt) mo:update(dt) end
function love.draw() mo:draw(240, 200, 0.6) end
```

That's the whole integration. Everything else in this README is what `mo`
can do once it's on screen.

Full API reference: [`docs/API.md`](docs/API.md).

## Try the demo first

```
love .
```
from the repo root (or build/open the packaged `.love`). See the header of
`main.lua` for the full key list — arrows to move, letters for reactions
(sarcastic/happy/surprised/confused/embarrassed/fuming/speechless/sad/
sleepy/determined/angry/glitch), `M` for the professor act, `SPACE` to
talk, `G` to sync to GitHub.

## Integrating into your own program

Copy the `minoru/` folder into your project's root (it's self-contained —
code + its own `assets/`). Then:

```lua
local Minoru = require("minoru")

local mo = Minoru.new({
  assetsPath = "minoru/assets/",        -- default, override if you moved it
  name = "Minoru⁶",                     -- speaker name in dialogue boxes
  saveFile = "my_game_minoru.json",     -- love.filesystem save path
  github = nil,                         -- see "Persona + GitHub sync" below
})

function love.update(dt) mo:update(dt) end
function love.draw() mo:draw(x, y, scale) end
```

From there, every method rig.lua/dialogue.lua/persona.lua expose is called
directly on `mo` (`mo:reactHappy()`, `mo:setMood("sad")`, `mo:say("...")`,
`mo:remember("likes", "tea")` — see below for the full list). You don't
need to know the internal module structure to use it; `mo.rig`, `mo.dialogue`
and `mo.persona` are still there if you want to reach past the facade for
something it doesn't wrap.

If you're not using LÖVE at all, the rig/visor/dialogue rendering code is
LÖVE-specific (`love.graphics.*`), but `minoru/json.lua` and the shape of
`minoru/persona.lua` (plain tables + `love.filesystem`) are simple enough to
port to another engine in an afternoon if you just want the persona/memory
half.

## What's in the box

- **Rig** (`rig.lua`) — helmet + 2 arms, each ending in a palm with 5
  fingers of 3 phalanges each. No legs — he floats. Real forward-kinematics
  (`love.graphics.push/translate/rotate`), mirrored for the right side from
  the same art (nothing is drawn twice). Pose changes animate smoothly
  (tweened, force-matched easing per reaction — see below) instead of
  snapping; always-on idle float bob plus occasional idle fidgeting so he's
  never perfectly frozen; a short mood-tinted motion trail when his position
  moves fast; equippable accessories (`equipAccessory("head", "prof_hat")`,
  `equipAccessory("handR", "pointer_stick")`).
- **Visor line** (`visor.lua`) — drawn live every frame, not swapped PNGs:
  continuous talk-amplitude animation, smooth cross-dissolve between moods,
  a pulsing "processing" dot loop, live glitch/tremble. 13 moods: standard,
  sarcastic, sad, angry, fuming (repressed anger), perplexed, happy,
  surprised, embarrassed, sleepy, determined, speechless, glitch.
- **Reactions** — `mo:reactHappy()`, `reactSarcastic()`, `reactSurprised()`,
  `reactConfused()`, `reactEmbarrassed()`, `reactSad()`, `reactSleepy()`,
  `reactDetermined()`, `reactAngry()`, `reactFuming()` (clenched fists +
  trembling), `reactSpeechless()` (slumped arms + sweat-drop icon),
  `reactGlitch()`, `reactMocking()` (professor hat + pointer), `reactIdle()`.
  Each bundles mood + pose + icon + grip/tremble — call the lower-level
  `setMood`/`setPose`/`setGrip`/`showIcon`/`setTremble` directly for
  anything custom. Transitions are tweened with a duration/easing matched to
  that reaction's "force" (`reactSurprised` snaps fast, `reactSleepy` eases
  in slow and heavy) — pass your own `{duration=, ease=}` to `setPose`/
  `setNamedPose`/`setGrip` for full control.
- **Talk gestures** — `mo:startTalking()` / `stopTalking()` animate the
  arms and visor together; `setTalkAmplitude(0..1)` every frame for real
  audio-reactive lip-sync instead of the built-in fallback pattern;
  `setTalkIntensity(0..1)` scales how big/fast the gestures are.
- **Dialogue box** (`dialogue.lua`) — typewriter reveal, SPDW-HUD styling
  (neon cyan border, magenta speaker name). `mo:say(text, onDone)`,
  `mo:advance()`.
- **Persona** (`persona.lua`) — updates on every interaction
  (`mo:touch({mood=, kind=, note=})`: counters, mood, a rolling log capped
  at 200 entries) AND keeps a durable knowledge base separate from that log:
  `mo:remember(key, value)` / `mo:recall(key)` / `mo:forget(key)`. Saved via
  `love.filesystem`, so it works the same on desktop and on muOS.
- **GitHub sync** (`sync.lua`) — `mo:syncPersona(callback)` pushes
  `persona.json`-equivalent state to a repo via the Contents API, in the
  background (a `love.thread`, see below) so it never freezes your frame
  loop. Set `autoSyncInterval` (seconds) in `Minoru.new()` to sync on a
  timer instead of calling it by hand.

## Persona + GitHub sync setup

Copy `secrets.example.lua` to `secrets.lua` (same folder as `main.lua`),
fill in `owner`/`repo`/`branch`/`path`/`token`, and keep it out of git (it's
already in `.gitignore`). **Use a fine-grained GitHub Personal Access Token
scoped to just that one repo's contents** — not a classic token with broad
access — especially if this ends up running on a handheld you might lend
out or lose. Then:

```lua
mo = Minoru.new({ github = require("secrets") })
mo:syncPersona(function(ok, err) print(ok, err) end)
```

Needs `curl` and `base64` on PATH (both are basically guaranteed on a Linux
desktop; verify they exist on your specific muOS build before relying on
this there — if either is missing, `syncPersona`'s callback reports the
failure explicitly rather than hanging).

## Testing

Pure-Lua, no LÖVE runtime required:
lua5.4 tests/test_json.lua # JSON round-trip + real anchors.json
lua5.4 tests/test_persona.lua # persona save/load/remember/forget
lua5.4 tests/test_dialogue.lua # UTF-8-safe typewriter (accents, "⁶")
lua5.4 tests/test_dialogue_interrupt.lua # onDone is never silently dropped
lua5.4 tests/test_rig.lua # forward-kinematics vs anchors.json
lua5.4 tests/test_tween.lua # pose-tweening: no snap, redirect, easing
lua5.4 tests/test_visor.lua # every mood x t x amp, fails on NaN/inf
lua5.4 tests/test_init.lua # the Minoru.new() facade + delegation
lua5.4 tests/test_sync.lua # Sync.pushFile with io.popen mocked

text

All nine run in CI on every push (`.github/workflows/ci.yml`), plus
`luac -p` on every `.lua` file and `luacheck .` with zero warnings allowed.


## Packaging
bash scripts/build.sh # -> dist/minoru-<version>.love
bash scripts/checksum.sh # -> dist/minoru-<version>.love.sha256
bash scripts/release.sh # build + checksum + next-step reminders

text

The `.love` is a plain zip built with a **whitelist** (only `conf.lua`,
`main.lua`, `minoru/`, `LICENSE`, `NOTICE.md`) — no tests, no docs, no
secrets, no VCS cruft. The CI builds it on every push and uploads it as an
artifact; on a `v*` tag it also attaches `.love` + `.sha256` to the GitHub
release automatically.

## Roadmap

- **v1.0 (this release)** — stable library, no known P0/P1 bugs.
- **v1.1** — performance profiling on RG35XX H: the visor renders ~150
  polygons + 150 circles + a stencil pass per frame at `N = 48`, and the
  motion trail draws up to 12 copies of the 1024×1024 helmet sprite. On
  low-power ARM this may not hold 60 FPS. Planned: adaptive `N`, per-mood
  shape cache, smaller trail budget, `quality` option in `Minoru.new`.
- **v2.0** — audio-driven lip-sync, TTS, LLM dialogue. Same constraint as
  GitHub sync: no native HTTPS in LÖVE, so this needs an external bridge.

## Known limitations

- No real audio capture — `setTalkAmplitude` is the hook, but you have to
  feed it from your own mic/analysis code. Without that, talking uses a
  believable auto-generated pattern instead.
- No text-to-speech; Minoru "talks" visually, produces no sound.
- Dialogue lines are hand-written in `main.lua`'s demo, not generated —
  hooking this up to an LLM for live dialogue is a natural next step but
  isn't included (would need an HTTP client; same constraint as GitHub sync).
- `curl`/`base64` dependency for sync is unverified on muOS specifically —
  check before relying on it there.

## License

Code is MIT (see `LICENSE`). The character art in `minoru/assets/` is not —
see `NOTICE.md`.
