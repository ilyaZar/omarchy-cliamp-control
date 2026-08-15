-- Discover effective CLIamp binds without depending on Hyprland's opaque
-- __lua dispatcher IDs.

local config = arg[1]
  or (os.getenv("HOME") .. "/.config/hypr/hyprland.lua")
local bindings = {}
local order = {}

local function dispatcher(kind, value)
  return {
    __cliamp_dispatcher = true,
    kind = kind or "",
    value = value or "",
  }
end

local function lua_literal(value)
  local value_type = type(value)

  if value_type == "string" then
    return string.format("%q", value)
  elseif value_type == "number" or value_type == "boolean" then
    return tostring(value)
  elseif value_type == "nil" then
    return "nil"
  end

  return "nil"
end

local function call_expression(path, ...)
  local values = {}
  for index = 1, select("#", ...) do
    values[index] = lua_literal(select(index, ...))
  end
  return path .. "(" .. table.concat(values, ", ") .. ")"
end

local function dsp_proxy(path)
  return setmetatable({ path = path }, {
    __index = function(self, key)
      return dsp_proxy(self.path .. "." .. tostring(key))
    end,
    __call = function(self, ...)
      local value = ...
      if self.path == "hl.dsp.exec_cmd" and type(value) == "string" then
        return dispatcher("exec", value)
      end
      return dispatcher("lua", call_expression(self.path, ...))
    end,
  })
end

local noop
noop = setmetatable({}, {
  __index = function()
    return noop
  end,
  __call = function()
    return noop
  end,
})

local function remember(keys, bind_dispatcher, opts)
  keys = tostring(keys or "")
  if keys == "" then
    return noop
  end

  local value = ""
  if type(bind_dispatcher) == "string" then
    value = bind_dispatcher
  elseif type(bind_dispatcher) == "table"
      and bind_dispatcher.__cliamp_dispatcher then
    value = bind_dispatcher.value
  end

  if bindings[keys] == nil then
    order[#order + 1] = keys
  end
  bindings[keys] = {
    keys = keys,
    description = tostring((opts or {}).description or ""),
    command = value,
  }
  return noop
end

hl = setmetatable({
  dsp = dsp_proxy("hl.dsp"),
  bind = remember,
  unbind = function(keys)
    bindings[tostring(keys or "")] = nil
    return noop
  end,
  get_active_window = function()
    return nil
  end,
  get_config = function()
    return nil
  end,
  get_monitors = function()
    return {}
  end,
}, {
  __index = function()
    return noop
  end,
})

local omarchy_path = os.getenv("OMARCHY_PATH") or "/usr/share/omarchy"
local bootstrap = omarchy_path .. "/default/hypr/bootstrap.lua"
local bootstrapped, bootstrap_error = pcall(dofile, bootstrap)
if not bootstrapped then
  io.stderr:write(
    "CLIamp binding bootstrap failed: " .. tostring(bootstrap_error) .. "\n"
  )
  os.exit(1)
end

local loaded, load_error = pcall(dofile, config)
if not loaded then
  io.stderr:write("CLIamp binding scan failed: " .. tostring(load_error) .. "\n")
  os.exit(1)
end

local function is_cliamp_binding(binding)
  local command = string.lower(binding.command)
    :gsub("['\"]", "")
    :gsub("%s+", " ")

  return string.find(
      command, "omarchy-launch-or-focus-tui cliamp", 1, true) ~= nil
    or string.find(command, "omarchy-launch-tui cliamp", 1, true) ~= nil
    or string.find(command, "toggle_cliamp.sh", 1, true) ~= nil
    or string.find(command, "quake_toggle.sh music", 1, true) ~= nil
end

local function json_string(value)
  return "\"" .. tostring(value or "")
    :gsub("\\", "\\\\")
    :gsub("\"", "\\\"")
    :gsub("\b", "\\b")
    :gsub("\f", "\\f")
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t") .. "\""
end

local matches = {}
for _, keys in ipairs(order) do
  local binding = bindings[keys]
  if binding and is_cliamp_binding(binding) then
    matches[#matches + 1] = binding
  end
end

table.sort(matches, function(left, right)
  local function priority(binding)
    local description = string.lower(binding.description)
    local command = string.lower(binding.command)
    if description == "cliamp drop-down"
        or string.find(command, "toggle_cliamp.sh", 1, true) then
      return 0
    elseif string.find(command, "quake_toggle.sh", 1, true) then
      return 1
    end
    return 2
  end

  local left_priority = priority(left)
  local right_priority = priority(right)
  if left_priority ~= right_priority then
    return left_priority < right_priority
  end
  return left.keys < right.keys
end)

io.write("[")
for index, binding in ipairs(matches) do
  if index > 1 then
    io.write(",")
  end
  io.write("{\"keys\":", json_string(binding.keys))
  io.write(",\"description\":", json_string(binding.description))
  io.write(",\"command\":", json_string(binding.command), "}")
end
io.write("]\n")
