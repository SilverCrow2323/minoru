-- tests/test_sync.lua — lua5.4 tests/test_sync.lua
-- Testa Sync.pushFile con io.popen mockato: niente rete, niente curl/base64
-- reali, niente token. Copre sha lookup, file nuovo, base64 vuoto, errore
-- API, cfg incompleto, network error (exit code), e la security fix di
-- Fase 4 (il token NON deve comparire nella command line).

package.path = package.path .. ";./?.lua"

local realOpen = io.open

local popenResponses = {}
local popenCalls = {}
local popenExitCode = 0
local lastPutPayload

io.popen = function(cmd)
  popenCalls[#popenCalls+1] = cmd
  local resp = ""
  for pat, r in pairs(popenResponses) do
    if cmd:match(pat) then resp = r; break end
  end
  local tmpPath = cmd:match("%-%-data%-binary @'([^']+)'")
  if tmpPath then
    local fh = realOpen(tmpPath, "r")
    if fh then lastPutPayload = fh:read("*a"); fh:close() end
  end
  local code = popenExitCode
  return {
    read = function(_, _) return resp end,
    close = function()
      if code == 0 then return true, "exit", 0 end
      return nil, "exit", code
    end,
  }
end

local Sync = dofile("minoru/sync.lua")

local failures = 0
local function check(cond, msg)
  if not cond then failures = failures + 1; print("  FAIL: " .. msg) end
end

local cfg = { owner = "o", repo = "r", token = "TOKEN", path = "p.json", branch = "main" }

-- 1. file esistente: GET trova sha, base64 ok, PUT risponde con content
do
  popenResponses = {
    ["%?ref="]     = '{"sha":"abc123","name":"p.json"}',
    ["base64"]     = "aGVsbG8=",
    ["%-X PUT"]    = '{"content":{"sha":"def456"}}',
  }
  popenExitCode = 0
  popenCalls = {}
  local ok, err = Sync.pushFile(cfg, "hello", "test commit")
  check(ok == true, "file esistente -> true (err=" .. tostring(err) .. ")")
  local sawGet, sawPut, sawB64 = false, false, false
  for _, c in ipairs(popenCalls) do
    if c:match("%?ref=")  then sawGet = true end
    if c:match("%-X PUT") then sawPut = true end
    if c:match("base64")  then sawB64 = true end
  end
  check(sawGet and sawPut and sawB64, "GET, base64, PUT tutti invocati")
end

-- 2. file nuovo: GET non trova sha, PUT senza sha nel payload
do
  popenResponses = {
    ["%?ref="]  = '{"message":"Not Found"}',
    ["base64"]  = "aGVsbG8=",
    ["%-X PUT"] = '{"content":{"sha":"new"}}',
  }
  popenExitCode = 0
  popenCalls = {}
  lastPutPayload = nil
  local ok, err = Sync.pushFile(cfg, "hello", "nuovo file")
  check(ok == true, "file nuovo -> true (err=" .. tostring(err) .. ")")
  check(lastPutPayload and not lastPutPayload:match('"sha"'), "file nuovo: payload PUT senza sha")
end

-- 3. base64 vuoto -> false
do
  popenResponses = {
    ["%?ref="] = '{"sha":"x"}',
    ["base64"] = "",
  }
  popenExitCode = 0
  local ok, err = Sync.pushFile(cfg, "x", "msg")
  check(ok == false, "base64 vuoto -> false")
  check(type(err) == "string" and err:match("base64"), "errore menziona base64 (got " .. tostring(err) .. ")")
end

-- 4. API PUT risponde con errore: false + messaggio
do
  popenResponses = {
    ["%?ref="]  = '{"sha":"x"}',
    ["base64"]  = "aGVsbG8=",
    ["%-X PUT"] = '{"message":"Bad credentials"}',
  }
  popenExitCode = 0
  local ok, err = Sync.pushFile(cfg, "x", "msg")
  check(ok == false, "PUT errore -> false")
  check(err == "Bad credentials", "errore API propagato (got " .. tostring(err) .. ")")
end

-- 5. cfg incompleto -> assert
do
  local ok = pcall(Sync.pushFile, { owner = "o" }, "x", "msg")
  check(ok == false, "cfg senza repo/token/path -> assert")
end

-- 6. network error: exit code != 0, body vuoto -> false con "curl exit"
do
  popenResponses = {
    ["%?ref="]  = "",
    ["base64"]  = "aGVsbG8=",
  }
  popenExitCode = 28  -- curl: operation timeout
  local ok, err = Sync.pushFile(cfg, "x", "msg")
  check(ok == false, "network error -> false")
  check(type(err) == "string" and err:match("curl exit 28"),
    "errore menziona curl exit 28 (got " .. tostring(err) .. ")")
end

-- 7. security fix Fase 4: il token NON deve comparire in nessuna command line
do
  popenResponses = {
    ["%?ref="]  = '{"sha":"x"}',
    ["base64"]  = "aGVsbG8=",
    ["%-X PUT"] = '{"content":{"sha":"y"}}',
  }
  popenExitCode = 0
  popenCalls = {}
  Sync.pushFile(cfg, "x", "msg")
  local leaked = false
  for _, c in ipairs(popenCalls) do
    if c:match("TOKEN") then leaked = true end
  end
  check(not leaked, "SECURITY: il token NON deve comparire nella command line di curl")
end

-- 8. la -K con il file di config curl viene passata a curl
do
  popenResponses = {
    ["%?ref="]  = '{"sha":"x"}',
    ["base64"]  = "aGVsbG8=",
    ["%-X PUT"] = '{"content":{"sha":"y"}}',
  }
  popenExitCode = 0
  popenCalls = {}
  Sync.pushFile(cfg, "x", "msg")
  local sawK = false
  for _, c in ipairs(popenCalls) do
    if c:match("%-K ") then sawK = true end
  end
  check(sawK, "curl -K <file config> deve essere usato per passare l'auth header")
end

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All sync tests passed (mocked io.popen, no network, token never on cmdline).")
end
