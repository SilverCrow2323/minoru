-- tests/test_json.lua — run with `lua5.4 tests/test_json.lua` from the repo root.
package.path = package.path .. ";./?.lua"
local json = dofile("minoru/json.lua")

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("  FAIL: " .. msg)
  end
end

-- round-trip a representative structure
local sample = {
  name = "Minoru\xE2\x81\xB6",
  mood = "standard",
  count = 12,
  ratio = 0.75,
  active = true,
  broken = false,
  log = {
    { t = 1, kind = "talk", note = "ciao \"mondo\"" },
    { t = 2, kind = "sync", note = "linea\ncon newline" },
  },
  facts = { likes = { value = "caffe corretto", updatedAt = 100 } },
}

local encoded = json.encode(sample)
local ok, decoded = pcall(json.decode, encoded)
check(ok, "decode should not error: " .. tostring(decoded))
if ok then
  check(decoded.name == sample.name, "name round-trips")
  check(decoded.count == 12, "integer round-trips")
  check(math.abs(decoded.ratio - 0.75) < 1e-9, "float round-trips")
  check(decoded.active == true and decoded.broken == false, "booleans round-trip")
  check(#decoded.log == 2, "array length preserved")
  check(decoded.log[1].note == 'ciao "mondo"', "escaped quotes round-trip")
  check(decoded.log[2].note == "linea\ncon newline", "newline round-trips")
  check(decoded.facts.likes.value == "caffe corretto", "nested object round-trips")
end

-- a real anchors.json-shaped payload, since that's what this actually parses in prod
local f = io.open("minoru/assets/anchors.json", "r")
if f then
  local raw = f:read("*a")
  f:close()
  local ok2, data = pcall(json.decode, raw)
  check(ok2, "anchors.json should decode: " .. tostring(data))
  if ok2 then
    check(type(data.helmet.shoulder_l) == "table" and #data.helmet.shoulder_l == 2, "shoulder_l is a 2-element array")
    check(type(data.palm.finger_bases) == "table" and #data.palm.finger_bases == 5, "palm has 5 finger_bases")
  end
else
  print("  (skipped anchors.json check — file not found at minoru/assets/anchors.json)")
end

if failures > 0 then
  print(failures .. " FAILURE(S)")
  os.exit(1)
else
  print("All json tests passed.")
end
