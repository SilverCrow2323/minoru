-- minoru/sync.lua
-- Pushes a file (e.g. persona.json) to a GitHub repo via the REST "contents"
-- API. Implemented by shelling out to `curl` + `base64` instead of a Lua
-- HTTPS library, because LÖVE ships no HTTPS client and muOS's bundled LÖVE
-- runtime may not have luasec available — curl/base64 are far more likely
-- to already exist on both a MX Linux desktop and a Linux-based handheld.
--
-- Requirements: curl and base64 on PATH; outbound internet on the device.
-- SECURITY: your GitHub token is passed on the command line and as an HTTP
-- header in plain text. Use a fine-grained Personal Access Token scoped to
-- ONLY this one repo's contents, keep it in secrets.lua (see
-- secrets.example.lua), and make sure secrets.lua is in .gitignore — never
-- commit it, and treat it as sensitive on a handheld you might lend out.
--
-- Sync.pushFile(...) below is BLOCKING (it shells out and waits) — fine to
-- call directly if you don't mind a hitch, e.g. from a script. For a
-- library embedded in someone else's real-time app, use
-- Sync.pushFileAsync(...) instead: it runs the same call on a love.thread
-- so the host's frame loop never stalls on a slow or hung network request.
-- You must call Sync.poll() once per frame (Minoru:update does this for you
-- if you're using the minoru.init facade) for its callback to ever fire.

local json = require("minoru.json")

local Sync = {}

local function shellEscape(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function runCapture(cmd)
  local h = io.popen(cmd .. " 2>&1")
  if not h then return nil, "io.popen unavailable" end
  local out = h:read("*a")
  h:close()
  return out
end

-- cfg = { owner, repo, token, path, branch = "main" (optional) }
-- content = raw string to write to that path in the repo
-- Returns true on success, or false + an error string.
function Sync.pushFile(cfg, content, commitMessage)
  assert(cfg and cfg.owner and cfg.repo and cfg.token and cfg.path,
    "sync: cfg needs owner, repo, token, path")
  local branch = cfg.branch or "main"
  local apiUrl = string.format("https://api.github.com/repos/%s/%s/contents/%s",
    cfg.owner, cfg.repo, cfg.path)
  local authHeader = shellEscape("Authorization: token " .. cfg.token)

  -- 1) look up the current sha (needed to UPDATE an existing file; a brand
  --    new file simply won't have one, and that's fine)
  local getCmd = string.format('curl -s -H %s -H "Accept: application/vnd.github+json" "%s?ref=%s"',
    authHeader, apiUrl, branch)
  local getOut = runCapture(getCmd)
  local sha = getOut and getOut:match('"sha"%s*:%s*"(.-)"')

  -- 2) base64-encode the content via a temp file (avoids shell-escaping
  --    arbitrary binary/text content by hand)
  local tmpIn = os.tmpname()
  local fin = io.open(tmpIn, "wb")
  fin:write(content)
  fin:close()
  local b64 = runCapture("base64 -w0 " .. shellEscape(tmpIn))
  os.remove(tmpIn)
  if not b64 or b64 == "" then return false, "base64 encoding failed (is `base64` installed?)" end

  -- 3) PUT the update
  local payload = {
    message = commitMessage or "Auto-update from Minoru\xE2\x81\xB6",
    content = (b64:gsub("%s+", "")),
    branch = branch,
  }
  if sha then payload.sha = sha end

  local tmpBody = os.tmpname()
  local fb = io.open(tmpBody, "w")
  fb:write(json.encode(payload))
  fb:close()

  local putCmd = string.format(
    'curl -s -X PUT -H %s -H "Accept: application/vnd.github+json" --data-binary @%s "%s"',
    authHeader, shellEscape(tmpBody), apiUrl)
  local putOut = runCapture(putCmd)
  os.remove(tmpBody)

  if putOut and putOut:match('"content"%s*:%s*{') then
    return true
  else
    local msg = putOut and putOut:match('"message"%s*:%s*"(.-)"')
    return false, msg or putOut or "unknown curl/API error"
  end
end

-- ---------------- async wrapper (love.thread) ----------------

local jobCounter = 0
local pendingCallbacks = {}
local resultChannel = nil

-- Same arguments as pushFile, plus an optional callback(ok, err) fired the
-- next time you call Sync.poll() after the background thread finishes.
-- Returns a jobId (mostly useful for logging); does not block.
function Sync.pushFileAsync(cfg, content, commitMessage, callback)
  assert(love.thread, "Sync.pushFileAsync needs love.thread (real LÖVE runtime, not the test harness)")
  jobCounter = jobCounter + 1
  local jobId = jobCounter
  resultChannel = resultChannel or love.thread.getChannel("minoru_sync_results")
  love.thread.getChannel("minoru_sync_job_" .. jobId):push({
    cfg = cfg, content = content, commitMessage = commitMessage, jobId = jobId,
  })
  pendingCallbacks[jobId] = callback
  local thread = love.thread.newThread("minoru/sync_worker.lua")
  thread:start(jobId)
  return jobId
end

-- Call this once per frame (Minoru:update does it for you) to fire any
-- pushFileAsync callbacks whose background job has finished.
function Sync.poll()
  if not resultChannel then return end
  local res = resultChannel:pop()
  while res do
    local cb = pendingCallbacks[res.jobId]
    pendingCallbacks[res.jobId] = nil
    if cb then cb(res.ok, res.err) end
    res = resultChannel:pop()
  end
end

return Sync
