std = "lua54"
globals = { "love" }
max_line_length = false
ignore = { "212", "213" }
files["tests/*.lua"] = {
  globals = { "love" },
  ignore = { "121" },
}

files["tests/test_sync.lua"] = {
  -- io.popen è read-only, ma lo sostituiamo di proposito per mockare curl/base64
  -- senza toccare la rete. Ignoriamo W122 solo su questo file.
  ignore = { "122" },
}
