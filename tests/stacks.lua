-- Layout checks for groups: nothing groups by itself, grouping is explicit, a
-- group in the middle can be stacked or tiled, and the resize keys still stop
-- where the middle window stops moving.
--
--   lua tests/stacks.lua

package.path = "./?.lua;" .. package.path
local h = require("tests.layout-harness")

local failures, checks = 0, 0
local function check(ok, what)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    io.write("FAIL ", what, "\n")
    return
  end
  io.write("ok   ", what, "\n")
end

-- Two windows of one app are their own slots until asked otherwise.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  check(#t.entries() == 2, "two terminals start as two slots")
  check(#t.entries()[1].targets == 1, "no grouping without asking")
end

-- Grouping is explicit: the focused window joins the group in the middle.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc() -- a terminal in the primary zone
  t.set_active(3):group():recalc() -- the other terminal joins it
  check(#t.entries() == 1, "the grouped terminals leave the column")
  check(t.parked() == 1, "the second terminal is parked behind the first")

  t.set_active(1)
  t.M.promote()
  t:recalc() -- the browser back in the primary zone
  local e = t.entries()
  check(#e == 1, "the group is one column entry")
  check(#e[1].targets == 2, "holding both terminals")
  check(e[1].targets[1].box.x == e[1].targets[2].box.x
    and e[1].targets[1].box.y == e[1].targets[2].box.y, "the pile shares one corner")
  check(e[1].targets[1].box.w < e[1].targets[2].box.w, "the front of the pile is the smaller box")
  local ok, why = t.in_bounds()
  check(ok, "the pile stays in the strip" .. (ok and "" or (": " .. tostring(why))))
end

-- A group can be taken apart again.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc()
  t.set_active(3):group():recalc()
  t.set_active(1)
  t.M.promote()
  t:recalc()
  check(#t.entries() == 1, "grouped")
  t.set_active(3):ungroup():recalc()
  check(#t.entries() == 2, "ungrouped back to two slots")
end

-- Tiling the group splits the primary zone between its windows.
do
  local t = h.load({ classes = { "chromium", "foot", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc()
  t.set_active(3):group():recalc()
  t.set_active(4):group():recalc()
  local zone = t.middle().w
  t.tile():recalc()
  local boxes = {}
  for i = 2, 4 do
    boxes[#boxes + 1] = t.targets[i].box
  end
  check(#t.entries() == 1, "the other app is still the only column entry")
  check(math.abs(boxes[1].w - zone / 3) < 1, "three windows split the zone in three")
  check(boxes[1].w == boxes[2].w and boxes[2].w == boxes[3].w, "equal panes")
  check(boxes[1].x < boxes[2].x and boxes[2].x < boxes[3].x, "side by side")
  check(boxes[1].y == boxes[2].y and boxes[2].y == boxes[3].y, "one row for three windows")
  t.tile():recalc()
  check(t.targets[2].box.w == t.middle().w and t.targets[3].box.w == t.middle().w,
    "stacking again puts them all in the one box")
end

-- A window moved to a special workspace is not part of the staging area.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" }, special = { 3 } }):recalc()
  local e = t.entries()
  check(#e == 1 and #e[1].targets == 1, "the scratchpad window is not in the strip")
end

-- Closing a window removes it from its group and dissolves the group.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc()
  t.set_active(3):group():recalc()
  check(#t.entries() == 1, "grouped before closing")
  t.close(3):recalc()
  check(#t.entries() == 1, "the group stays as one slot")
  check(#t.entries()[1].targets == 1, "with one window left")
  t.close(2):recalc()
  check(#t.entries() == 0, "the group is gone once its last window closes")
end

-- The column holds a limited number of entries; the rest park behind the middle.
do
  local classes = { "chromium" }
  for i = 1, 11 do
    classes[#classes + 1] = "app" .. i
  end
  local t = h.load({ classes = classes }):recalc()
  check(#t.entries() == 8, "the column keeps eight entries")
  check(t.parked() == 3, "the three oldest park behind the middle")
  local ok, why = t.in_bounds()
  check(ok, "the kept column stays in the strip" .. (ok and "" or (": " .. tostring(why))))
end

-- The resize keys stop where the middle window stops moving, and a press past
-- the end is not stored.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  for _ = 1, 8 do
    t.press(100)
  end
  local floor_width, stored = t.middle().w, t.state.saved
  for _ = 1, 3 do
    t.press(100)
  end
  check(t.middle().w == floor_width, "presses past the floor do not move the middle")
  check(t.state.saved == stored, "and they are not stored")
  t.press(-100)
  check(t.middle().w > floor_width, "one press back moves it immediately")
end

-- The two-sided layout keeps one entry per window: no grouping, no parking.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" }, thumb_side = "both" }):recalc()
  check(t.columns() == 2 and t.parked() == 0, "two-sided keeps one thumbnail per window")
end

io.write(string.format("\n%d checks, %d failed\n", checks, failures))
os.exit(failures == 0 and 0 or 1)
