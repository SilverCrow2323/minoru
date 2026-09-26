-- minoru/json.lua
-- Minimal dependency-free JSON encoder/decoder for LÖVE (desktop + muOS).
-- Supports objects, arrays, strings, numbers, booleans, null.
-- Not meant to be a full spec-complete parser (no \uXXXX escapes) — enough
-- for anchors.json and our own persona/state files.

local json = {}

-- ---------- encode ----------
local function isArray(t)
  local n = 0
  for k, _ in pairs(t) do
    if type(k) ~= "number" then return false end
    n = n + 1
  end
  for i = 1, n do
    if t[i] == nil then return false end
  end
  return true, n
end

local escapes = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encodeString(s)
  local out = s:gsub('[%c"\\]', function(c)
    return escapes[c] or string.format('\\u%04x', c:byte())
  end)
  return '"' .. out .. '"'
end

local encodeValue

local function encodeArray(t, n)
  local parts = {}
  for i = 1, n do
    parts[i] = encodeValue(t[i])
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function encodeObject(t)
  local parts = {}
  local i = 0
  for k, v in pairs(t) do
    i = i + 1
    parts[i] = encodeString(tostring(k)) .. ":" .. encodeValue(v)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

encodeValue = function(v)
  local tv = type(v)
  if v == nil then
    return "null"
  elseif tv == "boolean" then
    return v and "true" or "false"
  elseif tv == "number" then
    if v ~= v then return "0" end -- NaN guard
    return tostring(v)
  elseif tv == "string" then
    return encodeString(v)
  elseif tv == "table" then
    local arr, n = isArray(v)
    if arr then
      return encodeArray(v, n)
    else
      return encodeObject(v)
    end
  else
    error("json.encode: cannot encode type " .. tv)
  end
end

function json.encode(v)
  return encodeValue(v)
end

-- ---------- decode ----------
-- Small recursive-descent parser.
local function decodeError(s, i, msg)
  error(string.format("json.decode: %s at position %d near '%s'", msg, i,
    s:sub(math.max(1, i - 10), i + 10)))
end

local function skipWhitespace(s, i)
  local _, e = s:find("^[ \t\r\n]*", i)
  return e + 1
end

local parseValue

local function parseString(s, i)
  -- assumes s:sub(i,i) == '"'
  local j = i + 1
  local out = {}
  while true do
    local c = s:sub(j, j)
    if c == "" then decodeError(s, j, "unterminated string") end
    if c == '"' then
      return table.concat(out), j + 1
    elseif c == "\\" then
      local nc = s:sub(j + 1, j + 1)
      local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
      if map[nc] then
        out[#out + 1] = map[nc]
        j = j + 2
      elseif nc == "u" then
        local hex = s:sub(j + 2, j + 5)
        local code = tonumber(hex, 16) or 63
        out[#out + 1] = (code < 128) and string.char(code) or "?"
        j = j + 6
      else
        out[#out + 1] = nc
        j = j + 2
      end
    else
      out[#out + 1] = c
      j = j + 1
    end
  end
end

local function parseNumber(s, i)
  local m = s:match("^-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
  if not m or m == "" then decodeError(s, i, "invalid number") end
  return tonumber(m), i + #m
end

local function parseArray(s, i)
  local t = {}
  local n = 0
  i = skipWhitespace(s, i + 1)
  if s:sub(i, i) == "]" then return t, i + 1 end
  while true do
    local v
    v, i = parseValue(s, i)
    n = n + 1
    t[n] = v
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = skipWhitespace(s, i + 1)
    elseif c == "]" then
      return t, i + 1
    else
      decodeError(s, i, "expected ',' or ']'")
    end
  end
end

local function parseObject(s, i)
  local t = {}
  i = skipWhitespace(s, i + 1)
  if s:sub(i, i) == "}" then return t, i + 1 end
  while true do
    i = skipWhitespace(s, i)
    if s:sub(i, i) ~= '"' then decodeError(s, i, "expected string key") end
    local k
    k, i = parseString(s, i)
    i = skipWhitespace(s, i)
    if s:sub(i, i) ~= ":" then decodeError(s, i, "expected ':'") end
    i = skipWhitespace(s, i + 1)
    local v
    v, i = parseValue(s, i)
    t[k] = v
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = skipWhitespace(s, i + 1)
    elseif c == "}" then
      return t, i + 1
    else
      decodeError(s, i, "expected ',' or '}'")
    end
  end
end

parseValue = function(s, i)
  i = skipWhitespace(s, i)
  local c = s:sub(i, i)
  if c == '"' then
    return parseString(s, i)
  elseif c == "{" then
    return parseObject(s, i)
  elseif c == "[" then
    return parseArray(s, i)
  elseif c == "t" and s:sub(i, i + 3) == "true" then
    return true, i + 4
  elseif c == "f" and s:sub(i, i + 4) == "false" then
    return false, i + 5
  elseif c == "n" and s:sub(i, i + 3) == "null" then
    return nil, i + 4
  elseif c:match("[%-%d]") then
    return parseNumber(s, i)
  else
    decodeError(s, i, "unexpected character")
  end
end

function json.decode(s)
  local v = parseValue(s, 1)
  return v
end

return json
