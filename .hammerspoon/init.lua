-- Hammerspoon entrypoint.
--
-- Source of truth: `init.fnl` → compiled to `init.generated.lua` via:
--   `make hammerspoon`
--
-- This file stays small and stable so `~/.hammerspoon/init.lua` can remain a
-- symlink to it.

-- Enable the Hammerspoon CLI (`hs`) to connect for debugging.
do
  local ok, err = pcall(require, "hs.ipc")
  if not ok then
    local msg = "WARNING: failed to load hs.ipc (hs CLI won't work): " .. tostring(err)
    print(msg)
    if hs and hs.alert then hs.alert.show(msg, 3) end
  end
end

local home = os.getenv("HOME") or ""
local dotfiles = home .. "/dotfiles"
local generated = dotfiles .. "/.hammerspoon/init.generated.lua"

if hs and hs.fs and hs.fs.attributes(generated) == nil then
  local msg = "Missing Hammerspoon build output: run `cd ~/dotfiles && make hammerspoon`"
  print(msg)
  if hs and hs.alert then hs.alert.show(msg, 3) end
  return
end

local ok, err = pcall(function()
  dofile(generated)
end)

if not ok then
  local msg = "Hammerspoon config failed: " .. tostring(err)
  print(msg)
  if hs and hs.alert then hs.alert.show(msg, 3) end
end
