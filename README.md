# Stage Layout for Omarchy

A Stage Manager-style tiling layout for [Omarchy](https://omarchy.org/) on Hyprland.

This is a fork of [Sulejman/omarchy-stage](https://github.com/Sulejman/omarchy-stage).
It keeps upstream's two-sided layout and adds a one-sided strip, explicit
window groups, a stack you can see, and window actions for the omacast launcher.
`main` is upstream v1.1.0; `triston-custom`, the default branch here, is what
the install instructions below add. [How the one-sided layout works](docs/one-sided-layout.md)
has the long version.

The window you're working in sits alone in the middle of the screen. Every
other window on the workspace becomes a thumbnail in columns on the left and
right. Thumbnails are as big as the space allows: a few windows get one column
of large thumbnails, and more columns appear only when a column gets crowded,
each one further out a bit smaller.

Set `cfg.thumb_side` to `"left"` or `"right"` and every thumbnail goes down a
single column on that edge instead, with the middle window taking the whole
rest of the screen. Windows you group share a slot — the one used last is the
front of the pile, the rest sit behind it — and a group in the middle is pulled
out of the column entirely, either stacked behind its front window or tiled
across the primary zone.

Thumbnails keep their spot. Bringing a window into the middle swaps it with
the current middle window, and nothing else moves.

![Stage: a browser in the middle, other windows as thumbnails on both sides](docs/stage.png)

| Any window can take the middle | Narrow the middle and the thumbnails get more room |
|---|---|
| ![An image viewer in the middle](docs/stage-image.png) | ![A narrow editor in the middle with two thumbnail columns per side](docs/stage-narrow.png) |

## What this fork adds

The two-sided layout itself is upstream's, unchanged: with
`thumb_side = "both"` the workspace lays out exactly as it does upstream.

- **One-sided mode.** `cfg.thumb_side = "left"` (or `"right"`) keeps every
  thumbnail in one column on that edge. The strip is capped at one side's worth
  of the space and no wider than the column needs, so the middle window takes
  the rest, and the resize keys stop where it does instead of banking presses
  past the end.
- **Explicit groups.** Nothing groups by itself: two windows of the same app
  are two slots. `SUPER + CTRL + G` groups the focused window with the one in
  the middle, `SUPER + CTRL + SHIFT + G` takes it out, and `SUPER + SHIFT + T`
  tiles a group in the primary zone or stacks it again.
- **A stack you can see.** A stacked group fills the primary zone, so its front
  window is inset by `cfg.stack_deck` and the windows behind it show as a ring.
  Without that, a full-size stack looks exactly like one window.
- **Parking.** The column holds `cfg.stack_max` (8) entries; past that the
  least recently used windows wait behind the middle window, still in
  `ALT + TAB`, the way Stage Manager lets older apps fall off the screen.
- **Launcher actions.** Group, ungroup, tile or stack, swap into the middle,
  close, full screen and toggle floating are rows under **Windows** in omacast
  and Omarchy's own menu — no keys to remember.
- **Thumbnail clicks.** Clicking a thumbnail brings that window forward without
  delivering the press to the app — with or without the preview plugin
  (upstream PR #7).
- **Tests.** A stubbed-`hl` harness for the layout and group maths, plus the
  live thumbnail-click regression test.

Two Omarchy shortcuts give way to the group keys: Google Messages
(`SUPER + SHIFT + CTRL + G`) and Activity (`SUPER + SHIFT + T`) are unbound
when the layout loads. Delete the two `hl.unbind` lines next to the bindings in
`hypr/stage.lua` to get them back.

The one-sided layout is also upstream PR
[Sulejman/omarchy-stage#8](https://github.com/Sulejman/omarchy-stage/pull/8);
the groups, the stack ring and the launcher rows are fork-only for now.

## Keys

Stage is added as a third step to Omarchy's layout toggle. Other workspaces
keep Omarchy's normal bindings.

| Key | Action |
|---|---|
| `SUPER + L` | Cycle the workspace layout: dwindle → scrolling → stage → dwindle |
| Click a thumbnail | Swap it into the middle (for a pile, its last-used window; with stagethumbs, the click is consumed) |
| `SUPER + CTRL + G` | Group the focused window with the one in the middle |
| `SUPER + CTRL + SHIFT + G` | Take the focused window out of its group |
| `SUPER + SHIFT + T` | Tile the group in the middle, or stack it again |
| `ALT + TAB` / `ALT + SHIFT + TAB` | Switcher: hold `ALT` and tap `TAB` to move the highlight across the thumbnails (the left side first, inner column top to bottom, then the right side; `SHIFT` goes back), release `ALT` to open the highlighted one |
| `SUPER + arrows` | Move focus without moving anything (you can type into a thumbnail) |
| `SUPER + Z` | Swap the focused thumbnail into the middle |
| `SUPER + -` / `SUPER + =` | Widen / narrow the middle window (`ALT`: a little, `CTRL`: a lot). Thumbnails resize to use the space that's left |

## Groups

A group is a set of windows that share one slot, and it can mix apps. Nothing
groups by itself: a second window of the same app is simply a second window.

With the middle window focused — right after clicking a thumbnail, say — the
group key takes the window it was just swapped with, so click-then-key groups
the two you were using. Focus a thumbnail first with `SUPER + arrows` (which
moves focus without promoting anything) to group that window instead.

In the column a group is a pile: its windows share the slot's corner, the one
used last at the front and each window behind it a few pixels wider. In the
middle the group leaves the column and takes the primary zone, either stacked
behind its front window — `ALT + TAB` walks the full-size windows in place — or
tiled side by side (`SUPER + SHIFT + T`).

Groups belong to one workspace and live in memory: they survive windows opening
and closing, but not a config reload or the end of the session. A group reduced
to one window is a window again.

The same actions sit in omacast and in Omarchy's **Windows** menu — group,
ungroup, tile or stack, swap into the middle, close, full screen and toggle
floating — so they can be searched for instead of remembered;
`contrib/omarchy-menu-windows.jsonc` is the paste-in for
`~/.config/omarchy/extensions/omarchy-menu.jsonc`.

Which workspaces are in stage mode and how wide their middle window is are
remembered across reloads and logins.

## Requirements

- Omarchy with Hyprland **0.56 or newer** (stage is a Hyprland Lua layout)
- Optional, for real miniatures: `base-devel` (`make`, `g++`). Hyprland's
  headers ship with the `hyprland` package. Without them, stage still works
  and thumbnails are plain small windows. The miniatures are also x86_64 only;
  see [Miniature thumbnails](#miniature-thumbnails).
- Optional, to run the layout tests: a `lua` on `PATH`.

## Install

As an Omarchy plugin, from this fork:

```bash
omarchy plugin add https://github.com/tristonarmstrong/omarchy-stage --enable
```

The plugin id stays upstream's (`io.github.sulejman.stage`, from the manifest),
so update with `omarchy plugin update io.github.sulejman.stage`. To go back to
upstream, remove the plugin and add `https://github.com/Sulejman/omarchy-stage`.

Then press `SUPER + L` until the workspace switches to stage.

The plugin doesn't edit your Hyprland config. While it's enabled, it loads the
layout into the running Hyprland with `hyprctl eval`, and loads it again after
every config reload. On first start, and whenever the `hyprland` package
version changes, it builds the miniature-thumbnails plugin in its own folder
(a few seconds) and loads it with `hyprctl plugin load`.

### Manual install (alternative)

If you'd rather have stage in your Hyprland config than run it from the
shell, use the installer instead of the plugin, not both:

```bash
git clone https://github.com/tristonarmstrong/omarchy-stage.git
cd omarchy-stage
./install.sh
```

It copies `stage.lua`, `stage-maintain.sh` and the `stagethumbs/` source into
`~/.config/hypr/` (any file it would change is backed up as `*.bak.<time>`),
adds `require("hypr.stage")` to `~/.config/hypr/hyprland.lua`, installs two
Omarchy hooks that rebuild the thumbnails plugin after updates, then builds it
and reloads Hyprland. Update with `git pull && ./install.sh`.

## Miniature thumbnails

Without the thumbnails plugin, a thumbnail is the real window resized to a
small box, so apps re-lay themselves out for that size. The optional
`stagethumbs` Hyprland plugin instead keeps telling the app it has its full
middle-of-screen size and draws that content scaled down. Clicking a thumbnail
only brings it into the middle; neither the button press nor its release is
sent to the app. Click again in the centered window to interact with it.

The miniatures need Hyprland's function hooks, which are x86_64 only. On other
architectures the plugin loads without them: thumbnails stay plain windows, but
a primary click on one is still consumed and brings the window forward, so the
app sees neither the press nor the release. The layout says once per boot that
previews are off. Right and middle clicks pass through, and so do mouse
bindings on those buttons, because only the primary button is cancelled
there. The rest of the fork — one-sided strip, groups, stack ring, launcher
rows — is plain Lua and works everywhere.

Hyprland plugins must be built against the exact Hyprland version that's
running, so both install methods rebuild it when the `hyprland` package
changes. If a build fails, you get a notification, stage keeps working with
plain thumbnails, and the log is in `stagethumbs/build.log` (inside the plugin
folder, or `~/.config/hypr/stagethumbs/` for a manual install).

## Tuning

The `cfg` table at the top of `hypr/stage.lua` holds the knobs:

| knob | default | what it does |
|---|---|---|
| `thumb_side` | `"both"` | `"left"` or `"right"` for the single column on that edge |
| `stack_offset` | 8 | how far each window behind a column pile's front shows |
| `stack_spread` | 3 | most layers a pile fans out; deeper ones share the back |
| `stack_deck` | 12 | ring a full-size stack shows, on every side, per layer |
| `stack_max` | 8 | entries the column holds before the least recently used are parked |
| `center_aspect`, `center_min`, `center_max` | 1.6, 0.40, 0.64 | shape of the middle window and its share range |
| `center_step_min`, `center_step_max` | 0.25, 0.92 | range the resize keys move between |
| `decay` | 0.75 | how much narrower each further two-sided column is |
| `thumb_opacity`, `select_border` | 0.72, 4 | thumbnail opacity and selection border width |
| `swap_flash_ms` | 700 | how long the two windows of a swap light up |

With the plugin, edit
`~/.config/omarchy/plugins/io.github.sulejman.stage/hypr/stage.lua` and run
`hyprctl reload`. With a manual install, edit `~/.config/hypr/stage.lua`
(Hyprland reloads on save). Updates replace the file, so keep a note of your
changes.

## Tests

From the repository root, no compositor needed:

```bash
lua tests/stacks.lua      # 54 checks: column geometry, groups, parking, deck, tiling, resize floor
```

`tests/README.md` covers the live thumbnail-click regression test, which needs
a nested Hyprland and the virtual-pointer protocol.

## Uninstall

Plugin:

```bash
omarchy plugin remove io.github.sulejman.stage
```

Disabling or removing it reloads Hyprland, so stage workspaces fall back to
the default layout right away. The thumbnails plugin stays loaded but idle
until you log out. Saved stage state — which workspaces are in stage mode and
their middle widths — is in `~/.local/state/hypr-stage`. Delete that folder too
if you won't reinstall. Groups are in memory only and go with the session.

Manual install: run `./uninstall.sh`. It removes the files, hooks, `require`
line and saved state, then reloads Hyprland.

## Troubleshooting

- Errors inside stage's callbacks are logged to
  `~/.local/state/hypr-stage/errors.log`, because Hyprland's red error bar is
  cleared on every reload.
- Check for key conflicts with your own bindings:
  `omarchy menu keybindings --print`.
- The layout unbinds Google Messages and Activity to take their keys; if you
  use either, see [What this fork adds](#what-this-fork-adds).
- Launcher rows that seem to do nothing are usually a `hyprctl dispatch`
  command that isn't Lua: Omarchy 4 evaluates it as Lua and fails silently when
  run detached. The rows in `contrib/` use `hl.dsp`.

## Inspiration

Stage was inspired by Scott Jenson's talk
[*Are we really going to use the same Desktop UX forever?*](https://www.youtube.com/watch?v=V7AfAcQwLW0)
(The KDE Community), which questions whether desktop window management has
to stay the way it is.

[![Scott Jenson: Are we really going to use the same Desktop UX forever?](https://img.youtube.com/vi/V7AfAcQwLW0/hqdefault.jpg)](https://www.youtube.com/watch?v=V7AfAcQwLW0)

## License

MIT
