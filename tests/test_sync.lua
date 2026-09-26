-- tests/test_sync.lua — lua5.4 tests/test_sync.lua
-- Testa Sync.pushFile intercettando io.popen: niente rete, niente curl/base64
-- reali, niente token.

package.path = package.path .. ";./?.lua"

local realOpen = io.open

local popenResponses = {}
local popenCalls = {}
local lastPutPayload = nil
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
  return {
    read = function(_, _) return resp end,
    close = function() return true, "exit", 0 end,
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
    ["curl %-s %-H"]     = '{"sha":"abc123","name":"p.json"}',
    ["base64"]           = "aGVsbG8=",
    ["curl %-s %-X PUT"] = '{"content":{"sha":"def456"}}',
  }
  popenCalls = {}
  local ok, err = Sync.pushFile(cfg, "hello", "test commit")
  check(ok == true, "pushFile su file esistente true (err=" .. tostring(err) .. ")")
  local sawGet, sawPut, sawB64 = false, false, false
  for _, c in ipairs(popenCalls) do
    if c:match("curl %-s %-H")     then sawGet = true end
    if c:match("curl %-s %-X PUT") then sawPut = true end
    if c:match("base64")           then sawB64 = true end
  end
  check(sawGet and sawPut and sawB64, "GET, base64, PUT tutti invocati")
end

-- 2. file nuovo: GET non trova sha, PUT va comunque
do
  popenResponses = {
    ["curl %-s %-H"]     = '{"message":"Not Found"}',
    ["base64"]           = "aGVsbG8=",
    ["curl %-s %-X PUT"] = '{"content":{"sha":"new"}}',
  }
  popenCalls = {}
  lastPutPayload = nil
  local ok, err = Sync.pushFile(cfg, "hello", "nuovo file")
  check(ok == true, "pushFile su file nuovo true (err=" .. tostring(err) .. ")")
  check(lastPutPayload and not lastPutPayload:match('"sha"'), "file nuovo: payload PUT senza sha")
end

-- 3. base64 vuoto -> pushFile false
do
  popenResponses = {
    ["curl %-s %-H"] = '{"sha":"x"}',
    ["base64"]       = "",
  }
  local ok, err = Sync.pushFile(cfg, "x", "msg")
  check(ok == false, "base64 vuoto -> false")
  check(type(err) == "string" and err:match("base64"), "errore menziona base64 (got " .. tostring(err) .. ")")
end

-- 4. API PUT che risponde con errore
do
  popenResponses = {
    ["curl %-s %-H"]     = '{"sha":"x"}',
    ["base64"]           = "aGVsbG8=",
    ["curl %-s %-X PUT"] = '{"message":"Bad credentials"}',
  }
  local ok, err = Sync.pushFile(cfg, "x", "msg")
  check(ok == false, "PUT errore -> false")
  check(err == "Bad credentials", "errore API propagato (got " .. tostring(err) .. ")")
end

-- 5. cfg incompleto -> assert
do
  local ok = pcall(Sync.pushFile, { owner = "o" }, "x", "msg")
  check(ok == false, "cfg senza repo/token/path -> assert")
end

-- 6. test documentale: token in command line (fix previsto in Fase 4)
do
  popenResponses = {
    ["curl %-s %-H"]     = '{"sha":"x"}',
    ["base64"]           = "aGVsbG8=",
    ["curl %-s %-X PUT"] = '{"content":{"sha":"y"}}',
  }
  popenCalls = {}
  Sync.pushFile(cfg, "x", "msg")
  local leaked = false
  for _, c in ipairs(popenCalls) do
    if c:match("TOKEN") then leaked = true end
  end
  if leaked then
    print("  (nota) il token compare ancora nella command line: fix in Fase 4.")
  end
end

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All sync tests passed (mocked io.popen, no network).")
end
