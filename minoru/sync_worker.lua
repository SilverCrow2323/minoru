-- minoru/sync_worker.lua
-- Runs inside a love.thread started by Sync.pushFileAsync — this is what
-- keeps a slow or hung network call from freezing the host program's frame
-- loop. Do not require or run this file directly from the main thread.

local jobId = ...
local job = love.thread.getChannel("minoru_sync_job_" .. jobId):demand()

local Sync = require("minoru.sync")
local ok, err = Sync.pushFile(job.cfg, job.content, job.commitMessage)

love.thread.getChannel("minoru_sync_results"):push({
  jobId = jobId, ok = ok, err = err,
})
