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
    get_active_window = function() return state.active or windows[1] end,
    get_active_workspace = function() return ws end,
    get_workspace_windows = function() return windows end,
    get_config = function() return {} end,
    workspace_rule = function() end,
    unbind = function() end,
    dispatch = function() end,
    dsp = {
      layout = function(m) return m end,
      focus = function(o)
        if type(o) == "table" and o.window then
          state.active = o.window
        end
        return o
      end,
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
    -- Hyprland tells the window where it was put, which is what the arrow keys
    -- read to work out what is to the left of what.
    for _, tg in ipairs(targets) do
      tg.window.at = { x = tg.box.x, y = tg.box.y }
      tg.window.size = { x = tg.box.w, y = tg.box.h }
    end
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

  -- Pretend the given window (1-based) has focus, the way clicking it would.
  function t.set_active(i)
    state.active = windows[i]
    return t
  end

  -- The arrow keys: move focus without promoting, the way SUPER + LEFT does.
  function t.focus(dir)
    M.focus(dir)()
    return t
  end

  function t.group()
    M.group()
    return t
  end

  function t.ungroup()
    M.ungroup()
    return t
  end

  function t.tile()
    M.group_tile()
    return t
  end

  -- The window in the middle, according to the layout's slot order.
  function t.middle_id()
    local list = M.slots(1)
    return list and list[1]
  end

  function t.middle()
    local id = t.middle_id()
    for _, tg in ipairs(targets) do
      if tg.window.stable_id == id then
        return tg.box
      end
    end
    return targets[1].box
  end

  -- The primary zone: the biggest box on the workspace. With nothing grouped
  -- that is the middle window; with a stack it is the box the ones behind it
  -- fill, which is still the width the middle window had on its own.
  function t.zone()
    local out
    for _, tg in ipairs(targets) do
      local b = tg.box
      if not out or b.w > out.w then
        out = b
      end
    end
    return out
  end

  -- A box that stands in the primary zone: the middle window, the rest of its
  -- deck, and anything parked behind it.
  local function in_zone(box)
    local z = t.zone()
    return box.x == z.x and box.y == z.y and box.w == z.w and box.h == z.h
  end

  -- A thumbnail: narrower than the zone, against one of the strip's edges. The
  -- front of a deck is narrower too, but it is inset, so it is not in the strip.
  local function in_column(box)
    local z = t.zone()
    if box.w >= z.w or box.h >= z.h then
      return false
    end
    return box.x == AREA.x or box.x + box.w == AREA.x + AREA.w
  end

  -- Column entries: boxes outside the primary zone, grouped by the corner they
  -- share. Parked windows and the middle window are part of the zone.
  function t.entries()
    local by_corner, order = {}, {}
    for i, tg in ipairs(targets) do
      local b = tg.box
      if in_column(b) then
        local key = string.format("%.0f:%.0f", b.x, b.y)
        if not by_corner[key] then
          by_corner[key] = { x = b.x, y = b.y, targets = {}, w = 0 }
          order[#order + 1] = key
        end
        by_corner[key].w = math.max(by_corner[key].w, b.w)
        by_corner[key].targets[#by_corner[key].targets + 1] = tg
      end
    end
    table.sort(order, function(a, b) return by_corner[a].y < by_corner[b].y end)
    local out = {}
    for _, k in ipairs(order) do
      out[#out + 1] = by_corner[k]
    end
    return out
  end

  -- How many columns the thumbnails sit in: one for a single side, two for the
  -- two-sided layout.
  function t.columns()
    local seen, n = {}, 0
    for _, tg in ipairs(targets) do
      if in_column(tg.box) then
        local key = math.floor(tg.box.x)
        if not seen[key] then
          seen[key] = true
          n = n + 1
        end
      end
    end
    return n
  end

  -- The middle's group as it is drawn: boxes sorted front first, which is the
  -- smallest, inset one.
  function t.deck()
    local g = M.middle_group(1)
    local out = {}
    if not g then
      return out
    end
    for _, tg in ipairs(targets) do
      for _, id in ipairs(g.ids) do
        if tg.window.stable_id == id then
          out[#out + 1] = tg
        end
      end
    end
    table.sort(out, function(a, b) return a.box.w < b.box.w end)
    return out
  end

  -- Windows parked behind the middle: in the primary zone, but not the middle
  -- window and not one of its group.
  function t.parked()
    local mid = t.middle_id()
    local g = M.middle_group(1)
    local in_group = {}
    if g then
      for _, id in ipairs(g.ids) do
        in_group[id] = true
      end
    end
    local n = 0
    for _, tg in ipairs(targets) do
      local id = tg.window.stable_id
      if id ~= mid and not in_group[id] and in_zone(tg.box) then
        n = n + 1
      end
    end
    return n
  end

  -- Every thumbnail box inside the strip, and not running into the zone.
  function t.in_bounds()
    local z = t.zone()
    for _, tg in ipairs(targets) do
      local b = tg.box
      if in_column(b) then
        if b.x < AREA.x or b.y < AREA.y then
          return false, "box starts outside the area"
        end
        if b.x + b.w > AREA.x + AREA.w or b.y + b.h > AREA.y + AREA.h then
          return false, "box ends outside the area"
        end
        if b.x + b.w > z.x then
          return false, "box overlaps the middle window"
        end
      end
    end
    return true
  end

  return t
end

return H
