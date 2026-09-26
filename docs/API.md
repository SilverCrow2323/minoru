# Minoru⁶ — API reference

**Version:** `1.0.0-dev` (vedi `VERSION` / `Minoru.VERSION`).

Il modulo `minoru/` è autocontenuto: codice + `assets/`. Copialo nella root
del tuo progetto e fai `require("minoru")`.

## Quick start

    local Minoru = require("minoru")
    local mo = Minoru.new()

    function love.update(dt) mo:update(dt) end
    function love.draw()   mo:draw(240, 200, 0.6) end

## Costruttore

### Minoru.new(opts) -> mo

| opzione            | default                  | significato |
|--------------------|--------------------------|-------------|
| assetsPath         | "minoru/assets/"         | dove stanno le PNG del rig-kit |
| saveFile           | "minoru_persona.json"    | path love.filesystem per la persona |
| name               | "Minoru⁶"                | nome mostrato nella dialogue box |
| dialogue           | {}                       | passato a Dialogue.new |
| github             | nil                      | {owner,repo,token,path,branch} abilita :syncPersona() |
| autoSyncInterval   | nil                      | secondi; se settato, sync automatica |

## Ciclo di vita

- mo:update(dt) — ogni frame
- mo:draw(x, y, scale) — rig + dialogue box

## Reazioni

reactIdle, reactSarcastic, reactHappy, reactSurprised, reactConfused,
reactEmbarrassed, reactSad, reactSleepy, reactDetermined, reactAngry,
reactFuming, reactSpeechless, reactGlitch, reactMocking.

Le transizioni sono tweenate. Easing: linear, easeOutQuad, easeOutCubic,
easeInOutSine, easeOutBack, easeOutElastic.

## Posa e stato

- setMood(name) — standard|sarcastic|sad|angry|fuming|perplexed|happy|
  surprised|embarrassed|sleepy|determined|speechless|glitch
- setProcessing(on)
- setNamedPose(name, opts) — relaxed|slumped|akimbo|flinchBack|thinking|
  tenseFists|ready|teaching|crossedArms|shrug|wave|pointForward|armsWide|
  handsOnHips
- setPose(partial, opts) — es. {shoulderL=0.5, elbowR=-0.2}
- setGrip("L"|"R", 0..1, opts)
- setTremble(0..1)
- showIcon(name, dur) / hideIcon()
- equipAccessory("head"|"handL"|"handR", name)
- unequipAccessory(slot) / dropAllAccessories()

## Talking

- startTalking() / stopTalking()
- setTalkAmplitude(0..1) — lip-sync da audio reale
- setTalkIntensity(0..1) — ampiezza/velocità gesti

## Dialogue

- mo:say(text, onDone) — typewriter; se una linea precedente ha un
  onDone pendente, viene chiamato subito (fix v1.0.0-dev)
- mo:advance() — salta, poi chiude e chiama onDone
- mo.dialogue:isTyping() / :skip()

## Persona

- mo:touch({mood=, kind=, note=})
- mo:remember(k,v) / mo:recall(k) / mo:forget(k)
- mo.persona:allFacts()

## Sync GitHub (opzionale)

- mo:syncPersona(callback(ok, err)) — async via love.thread
- Richiede curl + base64 sul PATH
- SICUREZZA: il token compare nella command line di curl (visibile in ps).
  Usa un fine-grained PAT limitato al solo repo. Fix in Fase 4.

## Moduli interni

mo.rig, mo.dialogue, mo.persona, require("minoru.sync") per la sync.

## Test

lua5.4 tests/test_*.lua — 9 file, tutti in CI ad ogni push.
