-- Loads hypr/stage.lua against a stub Hyprland API, so the layout maths can be
-- exercised without a compositor. The stub mirrors what the plugin uses: the
-- window list for a workspace, the active window, the layout registration, the
-- resize bindings, and the centre state file.
--
--   local h = require("tests.layout-harness")
--   local t = h.load({ classes = { "foot", "foot", "chromium" } })
--   t.recalc()
--   print(t.middle().w, #t.column())

local H = {}

local AREA = { x = 10, y = 10, w = 1492, h = 962 }

-- The released file carries the opt-in default (thumbnails on both sides);
-- the machine runs it with one side, which is what most of these checks are
-- about. Stage the file with the value under test so both are covered.
local function staged_source(side)
  local f = assert(io.open("hypr/stage.lua", "r"))
  local body = f:read("a")
  f:close()
  body = body:gsub('thumb_side = "both"', 'thumb_side = "' .. side .. '"', 1)
  local path = os.tmpname()
  local out = assert(io.open(path, "w"))
  out:write(body)
  out:close()
  return path
end

local function state_dir()
  return os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
end

-- opts.classes  one entry per window; the first is the middle window
-- opts.adjust   the stored share adjustment for the workspace (default 0)
-- opts.special  1-based indexes of windows that live on a special workspace
function H.load(opts)
  opts = opts or {}
  local classes = opts.classes or { "chromium" }
  local special = {}
  for _, i in ipairs(opts.special or {}) do
    special[i] = true
  end

  local ws = {
    id = 1, name = "1", tiled_layout = "lua:stage", special = false,
    monitor = { width = 3024, height = 1964, scale = 2 },
  }
  local windows, targets, state = {}, {}, { adjust = opts.adjust or 0, saved = nil }

  local function make(i)
    local w = {
      stable_id = i, address = "0x" .. i,
      class = classes[i], title = classes[i] .. " " .. i,
      mapped = true, floating = false, tags = {},
      workspace = special[i] and { id = 900 + i, special = true } or ws,
      at = { x = 0, y = 0 }, size = { x = 0, y = 0 },
    }
    local t = { window = w, place = function(self, box) self.box = box end }
    return w, t
  end

  local function rebuild(list)
    windows, targets = {}, {}
    for _, i in ipairs(list) do
      local w, t = make(i)
      windows[#windows + 1] = w
      targets[#targets + 1] = t
    end
  end
  local ids = {}
  for i = 1, #classes do
    if not special[i] then
      ids[#ids + 1] = i
    end
  end
  rebuild(ids)

  local layout
  local hl = {
    layout = { register = function(_, c) layout = c end },
    on = function() end,
    timer = function() end,
    get_active_window = function() return windows[1] end,
    get_active_workspace = function() return ws end,
    get_workspace_windows = function() return windows end,
    get_config = function() return {} end,
    workspace_rule = function() end,
    unbind = function() end,
    dispatch = function() end,
    dsp = {
      layout = function(m) return m end,
      focus = function(o) return o end,
      window = { tag = function() end, set_prop = function() end },
    },
    exec_cmd = function() end,
  }

  local env = setmetatable({
    hl = hl,
    o = { window = function() end, bind = function() end },
    io = {
      open = function(name, mode)
        if name ~= state_dir() .. "/center" then
          return nil
        end
        if mode == "r" then
          local done = false
          return {
            lines = function()
              return function()
                if done then return nil end
                done = true
                return "1 " .. state.adjust
              end
            end,
            close = function() end,
          }
        end
        return {
          write = function(_, ...)
            state.saved = table.concat({ ... }, "")
          end,
          close = function() end,
        }
      end,
    },
    os = { getenv = os.getenv, execute = function() end, date = os.date },
    stage_runtime = true,
  }, { __index = _G })
  env._G = env

  local src = opts.source or staged_source(opts.thumb_side or "left")
  local M = assert(loadfile(src, "t", env))()

  local t = {
    areas = AREA, state = state, layout = layout, M = M,
    targets = targets, windows = windows,
  }

  function t.recalc()
    layout.recalculate({ area = AREA, targets = targets })
    return t
  end

  function t.press(dx)
    M.resize(dx)()
    t.recalc()
    return t
  end

  function t.close(index)
    table.remove(targets, index)
    table.remove(windows, index)
    return t
  end

  function t.middle()
    return targets[1].box
  end

  -- One entry per slot: windows that share the same corner. Parked windows
  -- sit in the middle window's box and are not entries.
  function t.entries()
    local m = t.middle()
    local by_corner, order = {}, {}
    for i = 2, #targets do
      local b = targets[i].box
      local parked = b.x == m.x and b.y == m.y and b.w == m.w
      if not parked then
        local key = string.format("%.0f:%.0f", b.x, b.y)
        if not by_corner[key] then
          by_corner[key] = { x = b.x, y = b.y, targets = {}, w = 0 }
          order[#order + 1] = key
        end
        by_corner[key].w = math.max(by_corner[key].w, b.w)
        by_corner[key].targets[#by_corner[key].targets + 1] = targets[i]
      end
    end
    table.sort(order, function(a, b) return by_corner[a].y < by_corner[b].y end)
    local out = {}
    for _, k in ipairs(order) do
      out[#out + 1] = by_corner[k]
    end
    return out
  end

  -- How many columns the entries sit in: one for a single side.
  function t.columns()
    local seen, n = {}, 0
    for _, e in ipairs(t.entries()) do
      local key = math.floor(e.x)
      if not seen[key] then
        seen[key] = true
        n = n + 1
      end
    end
    return n
  end

  -- Thumbnail boxes that share the middle window's box: parked windows.
  function t.parked()
    local m = t.middle()
    local n = 0
    for i = 2, #targets do
      local b = targets[i].box
      if b.x == m.x and b.y == m.y and b.w == m.w then
        n = n + 1
      end
    end
    return n
  end

  -- Every thumbnail box inside the strip and not overlapping the middle.
  function t.in_bounds()
    local m = t.middle()
    for i = 2, #targets do
      local b = targets[i].box
      if b.x < AREA.x or b.y < AREA.y then
        return false, "box starts outside the area"
      end
      if b.x + b.w > AREA.x + AREA.w or b.y + b.h > AREA.y + AREA.h then
        return false, "box ends outside the area"
      end
      local parked = b.x == m.x and b.y == m.y and b.w == m.w
      if not parked and b.x + b.w > m.x then
        return false, "box overlaps the middle window"
      end
    end
    return true
  end

  return t
end

return H
