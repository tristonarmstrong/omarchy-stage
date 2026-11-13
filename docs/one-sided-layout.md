# Stage with the thumbnails on one side

Stage balances a workspace between two thumbnail strips. `cfg.thumb_side` puts
every thumbnail on one edge instead, which hands the width of the other strip
to the window you are working in. This is the layout the one-sided patch adds;
the two-sided layout is untouched.

```lua
thumb_side = "left",   -- "both" (default), "left" or "right"
```

## What gets laid out

The middle window keeps the width its share gives it, and `SUPER + -` / `SUPER
+ =` still resize it by that share (`center_step_min` to `center_step_max`).
On one side the strip is **at most one side's worth** of what the share leaves
— `area.w * (1 - share) / 2`, the same width one strip gets in the two-sided
layout — so the middle window is at least `(1 + share) / 2` of the screen.

The thumbnails sit in a **single column** against the edge, largest they can
be within that strip:

| quantity | rule |
| --- | --- |
| column width | `min(strip, area.h / count * aspect)` |
| thumbnail height | `min(area.h / count, strip / aspect)` |
| thumbnail width | height × `aspect` |
| vertical position | centred in the screen |

`count` is the number of **entries** in the column, not the number of windows:
windows you have grouped share a slot (see below).

`aspect` is the middle window's shape at its default width,
`area.w * default_share(area) / area.h`, so a thumbnail is a scaled copy of the
window rather than a different shape. With a handful of windows the column is
as wide as the strip and each thumbnail is that size; add more windows and
they shrink to share the height. The column is never split into a second
column.

Because the strip is only ever as wide as the column needs, the middle window
takes the rest: that is what stops `SUPER + -` from shrinking it past the point
where the column would leave a band of wallpaper, and why the middle window can
grow slightly when thumbnails are added (they get smaller, so the column needs
less width). `SUPER + =` still widens it, which shrinks the thumbnails.

At the default share on a 1512x982 output (a 1492x962 tiling area), the middle
window is 1223 px wide and the strip 269 px:

| entries in the column | each slot | middle window |
| --- | --- | --- |
| 1 to 3 | 269 by 271 | 1223 |
| 4 | 239 by 240 | 1253 |
| 6 | 159 by 159 | 1333 |
| 8 | 119 by 119 | 1373 |

## Groups

Nothing groups by itself: two windows of the same app are two slots. A group is
something you make:

| key | what it does |
| --- | --- |
| `SUPER + CTRL + G` | put the focused window into the group in the middle, starting the group with the middle window |
| `SUPER + CTRL + SHIFT + G` | take the focused window back out; a group of one is just a window again |
| `SUPER + SHIFT + T` | tile the group in the middle, or stack it again |

Two ways to use it, depending on what has focus:

- Nothing else selected (the window in the middle has focus, e.g. right after
  clicking a thumbnail): the key groups the middle with the window it was
  swapped with, so clicking a window and pressing the key groups the two you
  were just using.
- A thumbnail focused with `SUPER + arrows` (which moves focus without promoting
  anything): the key puts that window into the middle's group.

Groups are per workspace and last as long as their windows do.

Two Omarchy shortcuts step aside for these keys: Google Messages
(`SUPER + SHIFT + CTRL + G`) and Activity (`SUPER + SHIFT + T`) are unbound by
the plugin on load. Delete the two `hl.unbind` lines next to the bindings in
`stage.lua` to give them back.

**In the column** a group is one slot holding a pile: its windows share the
slot's corner, the one used last at the front with the smallest box, and each
one behind it a `cfg.stack_offset` (8 px) wider and taller, up to
`cfg.stack_spread` (3) layers. Hyprland draws the window focused last on top,
so the front has to be the window used last; the layout tracks that per
workspace where the swaps happen. A pile that got this wrong would hide behind
its own back.

**In the middle** the group leaves the column entirely and takes the primary
zone, in one of two modes:

- **stacked** (default): the front window at full size, its group's other
  windows in the same box behind it. `ALT + TAB` walks them and brings each one
  forward in place, so switching between the full versions of a group's windows
  happens in the primary zone.
- **tiled** (`SUPER + SHIFT + T`): the primary zone splits between the group's
  windows — side by side for two or three, a grid for more — so a group of
  terminals can all be watched at once.

The column holds `cfg.stack_max` entries (8). Past that the least recently used
ones are parked behind the middle window, still on `ALT + TAB`, the way Stage
Manager lets older apps fall off the side of the screen.

## Keys

Everything keeps working as documented in the README. The two places where one
side changes behaviour:

- `SUPER + -` / `SUPER + =` narrow and widen the middle window as usual, and
  stop when the column cannot get any wider. They stop *there*, not at the
  share's own limit, so presses past the end are not stored: pressing the
  other key once moves the window straight away instead of first burning off
  the extra presses. On a three-thumbnail workspace there are three steps of
  `SUPER + =` from the widest middle window to the floor, and no more.
- `ALT + TAB` walks the single column from top to bottom instead of visiting
  the left side and then the right, so the switcher follows what is on screen.
  The window in the middle is in the walk too, which is how its group's other
  windows and the parked ones come forward.
- Clicking a pile brings its front window into the middle, which also pulls the
  rest of that group out of the column. Moving between the windows of the group
  now in the middle is `ALT + TAB`, or tiling it with `SUPER + SHIFT + T`.

`switch_order` handles that: with `thumb_side` set, slot order is already the
order on screen, so it walks slots 2..n.

## Where it lives in the code

- `fill_column` places the single column. It is only called when `thumb_side`
  is set.
- `fill_side` is the released two-sided layout, unchanged, so `thumb_side =
  "both"` renders exactly as upstream does.
- The slot list, swapping, the switcher, the resize handling and the highlight
  tags are shared with the two-sided layout.

## Fullscreen and windows that leave

A fullscreen window takes the monitor from Hyprland itself, so the column is
simply covered and comes back when the window leaves fullscreen; the layout
does not need to know about it.

A window moved to a special workspace (the scratchpad, `SUPER + ALT + S`) is
not a window of the workspace any more, so it is not in the column and not
parked behind the middle either: `ALT + TAB` and the layout stop seeing it
until it comes back. Closing the last window of a group removes the entry, and
a group that is down to one window is a window again.

## What Stage Manager does that this does not

Kept here so the gaps are a decision rather than an oversight:

- **A Control Center switch.** Stage is a layout: `SUPER + L` cycles to it, and
  the `cfg` table is the configuration. A toggle would be a second way to say
  the same thing.
- **A preview of an app's windows from its sidebar icon.** There is no overlay
  to draw one in, and on this machine thumbnails show no live content either
  (see the limitation below). The equivalent here is `ALT + TAB`, which brings
  each window forward in place.
- **Dragging apps together into sets.** Sets exist here, but they are made with
  `SUPER + CTRL + G` rather than by dragging: this layout is auto-tiling, there
  is no canvas to drop onto, and nothing in it depends on the pointer dragging
  a window.
- **Clicking the desktop to clear the stage.** Hyprland has no desktop surface.
  The scratchpad (`SUPER + S`, `SUPER + ALT + S`) already empties the screen
  when that is what you want.

## Limitations

- The strip is limited to one side's worth, so a very narrow middle window is
  not possible on one side: the column has a minimum width it needs. That is
  deliberate; the alternative is a gap between the column and the window.
- The pile shows as a few pixels of edge, so it reads better with a wallpapered
  background than against a busy window; there is no badge to say how deep it
  is.
- A group belongs to one workspace and is forgotten when its windows close or
  the session restarts, like the slot order itself.
- The window in the middle is the anchor for `SUPER + CTRL + G`, so there is no
  way to group two windows that are both in the column without bringing one of
  them forward first.
- Miniature thumbnails (the `stagethumbs` plugin) need Hyprland's function
  hooks, which only exist on x86_64. On other architectures the plugin cannot
  load, `stage-service.sh` notices once per boot, and thumbnails stay plain
  windows. Clicking a plain thumbnail still promotes it through the normal
  focus path.

## Testing notes

The layout maths was checked with a stubbed `hl` (no compositor needed): the
window count and every resize step were swept, asserting that thumbnails stay
in one column, never exceed the strip, always fit the height, and always sit
against the middle window with only the usual window gap between them. On a
live session, `hyprctl clients -j` gives the geometry to compare against the
tables above.

Upstream pull request: Sulejman/omarchy-stage#8.
