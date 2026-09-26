std = "lua54"
globals = { "love" }
max_line_length = false
ignore = { "212", "213" }
files["tests/*.lua"] = {
  globals = { "love" },
  ignore = { "121" },
}
