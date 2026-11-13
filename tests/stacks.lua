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
  check(t.parked() == 0, "nothing is parked: this is a stack, not overflow")
  local deck = t.deck()
  check(#deck == 2, "the middle holds both terminals")
  check(deck[1].box.w < deck[2].box.w, "the front is the smaller box")
  check(deck[2].box.w == t.zone().w and deck[2].box.h == t.zone().h,
    "the one behind it fills the primary zone")
  check(deck[1].box.x - deck[2].box.x == deck[1].box.y - deck[2].box.y,
    "the front is inset the same amount from the top as from the left")
  check(deck[2].box.x + deck[2].box.w - (deck[1].box.x + deck[1].box.w)
    == deck[2].box.y + deck[2].box.h - (deck[1].box.y + deck[1].box.h),
    "and the same from the bottom as from the right")
  check(deck[1].window.stable_id == t.middle_id(), "the window in front is the one in the middle")

  t.set_active(1)
  t.M.promote()
  t:recalc() -- the browser back in the primary zone
  local e = t.entries()
  check(#e == 1, "the group is one column entry")
  check(#e[1].targets == 2, "holding both terminals")
  local a, b = e[1].targets[1], e[1].targets[2]
  local front, behind = a, b
  if b.box.w < a.box.w then
    front, behind = b, a
  end
  check(a.box.x == b.box.x and a.box.y == b.box.y, "the pile shares one corner")
  check(front.box.w < behind.box.w, "the front of the pile is the smaller box")
  check(front.window.stable_id == 2, "the middle window is the front of the pile")
  local ok, why = t.in_bounds()
  check(ok, "the pile stays in the strip" .. (ok and "" or (": " .. tostring(why))))
end

-- With the middle focused, grouping takes the window it was swapped with, so
-- clicking a window and pressing the key groups the two you were just using.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc()
  t:group():recalc() -- still on the promoted window, no arrow focus
  check(t.middle_id() == 2, "the clicked window is still the middle")
  check(#t.entries() == 1, "the window it swapped with joined its group")
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
  local zone = t.zone().w -- the back of the deck: the primary zone itself
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
  local deck = t.deck()
  check(#deck == 3, "stacking again puts the three in one deck")
  check(math.abs(deck[3].box.x - (t.areas.x + t.entries()[1].w)) < 1
    and math.abs(deck[3].box.x + deck[3].box.w - (t.areas.x + t.areas.w)) < 1,
    "the back of the deck is the primary zone, not the strip")
  check(deck[3].box.w == zone and deck[3].box.h == t.zone().h, "the back fills the zone")
  check(deck[3].box.w - deck[2].box.w == deck[2].box.w - deck[1].box.w,
    "each layer is inset one step more than the one behind it")
  check(deck[1].window.stable_id == t.middle_id(), "the front is the window in the middle")
end

-- Focusing a thumbnail with the arrows is not a promotion, but the window is
-- still the one in use: it moves to the front of the deck, because the deck
-- draws the window focused last on top.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc()
  t.set_active(3):group():recalc()
  check(t.deck()[1].window.stable_id == 2, "the middle window starts in front")
  t.focus("l"):recalc()
  check(t.middle_id() == 2, "the arrows do not promote")
  check(t.state.active.stable_id == 1, "they land on the thumbnail to the left")
  t.group():recalc()
  check(#t.deck() == 3, "the thumbnail the arrows landed on joins the group")
  check(t.deck()[1].window.stable_id == 1, "and goes to the front of the deck")
  check(t.deck()[1].box.w < t.deck()[2].box.w, "as the smallest box, so nothing covers it")
end

-- A lone middle window fills the primary zone: the ring only appears when
-- there really are windows behind it.
do
  local t = h.load({ classes = { "chromium", "foot" } }):recalc()
  check(#t.deck() == 0 and t.middle().w == t.zone().w and t.middle().x == t.zone().x,
    "one window in the middle fills the zone, with no ring")
end

-- The deck is only shown stacked: tiled panes do not overlap, so they need no
-- ring either.
do
  local t = h.load({ classes = { "chromium", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc()
  t.set_active(3):group():recalc()
  local zone = t.zone().w
  t.tile():recalc()
  local d = t.deck()
  check(#d == 2, "both group members are placed")
  check(d[1].box.x ~= d[2].box.x, "tiled panes sit side by side, not on top of each other")
  check(math.abs(d[1].box.w - zone / 2) < 1 and math.abs(d[2].box.w - zone / 2) < 1,
    "each pane takes half the zone, and neither is inset")
end

-- Past cfg.stack_spread layers the extra windows share the back of the deck.
do
  local t = h.load({ classes = { "chromium", "foot", "foot", "foot", "foot" } }):recalc()
  t.set_active(2)
  t.M.promote()
  t:recalc()
  for i = 3, 5 do
    t.set_active(i):group():recalc()
  end
  local d = t.deck()
  check(#d == 4, "the middle holds all four terminals")
  check(d[3].box.w == d[4].box.w and d[3].box.x == d[4].box.x,
    "beyond the spread the deepest windows share the back")
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
