-- Layout checks for stacks: one strip entry per app, the middle app pulled out
-- and parked behind the middle window, and the resize keys still stopping where
-- the middle window stops moving.
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

-- One entry per app, with the windows of the app fanned in it.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  local entries = t.entries()
  check(#entries == 1, "two terminals make one entry")
  local boxes = entries[1] and entries[1].targets or {}
  check(#boxes == 2, "that entry holds both windows")
  check(boxes[1] and boxes[2] and boxes[1].box.x == boxes[2].box.x
    and boxes[1].box.y == boxes[2].box.y, "the stack shares one corner")
  check(boxes[1] and boxes[2] and boxes[1].box.w < boxes[2].box.w,
    "the front of the pile is the smaller box")
  check(boxes[2] and boxes[2].box.w == entries[1].w, "the back of the pile fills the slot")

  local ok, why = t.in_bounds()
  check(ok, "boxes stay in the strip" .. (ok and "" or (": " .. tostring(why))))
end

-- The app in the middle is not in the strip; its other windows sit behind it.
do
  local t = h.load({ classes = { "chromium", "chromium", "foot" } }):recalc()
  check(#t.entries() == 1, "the middle app is pulled out of the strip")
  check(t.parked() == 1, "its other window is parked behind the middle")
end

-- An app whose windows are all in the middle leaves the column empty.
do
  local t = h.load({ classes = { "chromium", "chromium" } }):recalc()
  check(#t.entries() == 0, "no entries when the only app is the middle one")
  check(t.middle().w == t.areas.w, "the middle window takes the whole area")
end

-- Mixed apps, deeper stacks, everything inside the strip.
do
  local t = h.load({ classes = {
    "chromium", "foot", "foot", "chromium",
    "foot", "htop", "htop", "htop", "foot",
  } }):recalc()
  check(#t.entries() == 2, "three apps in the strip: foot and htop")
  local ok, why = t.in_bounds()
  check(ok, "mixed stack stays inside the strip" .. (ok and "" or (": " .. tostring(why))))
end

-- A window moved to a special workspace is not part of the staging area.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" }, special = { 3 } }):recalc()
  local e = t.entries()
  check(#e == 1 and #e[1].targets == 1, "the scratchpad window is not in the strip")
end

-- Closing the last window of an app dissolves its entry.
do
  local t = h.load({ classes = { "chromium", "foot", "htop", "htop" } }):recalc()
  check(#t.entries() == 2, "two apps before closing")
  t.close(2):recalc() -- one htop
  t.close(2):recalc() -- the other htop
  check(#t.entries() == 1, "the entry is gone once its last window closes")
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

-- The two-sided layout keeps one entry per window: no stacks, no parking.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" }, thumb_side = "both" }):recalc()
  check(#t.entries() == 2, "two-sided keeps one thumbnail per window")
  check(t.parked() == 0, "two-sided parks nothing")
end

io.write(string.format("\n%d checks, %d failed\n", checks, failures))
os.exit(failures == 0 and 0 or 1)
