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

| thumbnails | each thumbnail | middle window |
| --- | --- | --- |
| 3 | 269 by 271 | 1223 |
| 4 | 239 by 240 | 1253 |
| 6 | 159 by 159 | 1333 |
| 8 | 119 by 119 | 1373 |

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

`switch_order` handles that: with `thumb_side` set, slot order is already the
order on screen, so it walks slots 2..n.

## Where it lives in the code

- `fill_column` places the single column. It is only called when `thumb_side`
  is set.
- `fill_side` is the released two-sided layout, unchanged, so `thumb_side =
  "both"` renders exactly as upstream does.
- The slot list, swapping, the switcher, the resize handling and the highlight
  tags are shared with the two-sided layout.

## Limitations

- The strip is limited to one side's worth, so a very narrow middle window is
  not possible on one side: the column has a minimum width it needs. That is
  deliberate; the alternative is a gap between the column and the window.
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
