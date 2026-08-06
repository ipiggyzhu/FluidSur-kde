# FluidSur GTK

The GTK half of FluidSur. It exists for one reason: GTK applications draw their
own window frames, so the Aurorae decoration that gives native KDE applications
their FluidSur window buttons never reaches them. Without this component, Firefox
and every other GTK application on the desktop fall back to Breeze and look
out of place.

## What it covers

| Toolkit | Result |
|---|---|
| GTK 3 | Full theme, FluidSur window buttons |
| GTK 4 | Full theme, FluidSur window buttons |
| GTK 2 | Widget styling only (GTK 2 has no client-side decorations) |
| libadwaita | Opt-in via `--libadwaita`; these applications ignore the system theme by design |
| Chromium-based browsers | Window buttons only, and only with *Use GTK* selected (see below) |

Chrome and other Chromium browsers draw their own frame, but they can be told
to take it from GTK. Under *Settings → Appearance → Customise your Chrome →
Window frame*, pick **GTK** rather than the built-in look. Chrome then builds a
synthetic `headerbar.header-bar.titlebar button.titlebutton` node, which the
theme's regular titlebutton rules match, and the FluidSur buttons appear. Only the
frame follows the GTK theme — the tab strip, toolbar and menus stay on Chrome's
own styling.

Alternatively, *Settings → Appearance → Use system title bar and borders* hands
the whole frame back to KWin and therefore to the FluidSur Aurorae decoration.
That gives a fully native title bar at the cost of Chrome's tabs-in-titlebar
layout.

## Build requirements

```
sudo dnf install sassc glib2-devel      # Fedora
sudo apt install sassc libglib2.0-dev   # Debian/Ubuntu
```

`glib-compile-resources` is required because the theme ships as a gresource
bundle: the installed `gtk.css` is a single `@import` pointing into
`gtk.gresource`, which is what lets the compiled stylesheet reference the
window-button images by relative path.

## Usage

The top-level `../install.sh` builds this automatically. To build it alone:

```bash
./install.sh                      # both colour variants into ~/.themes
./install.sh --color dark         # dark only
./install.sh --theme purple       # accent colour
./install.sh --alt                # window buttons without hover symbols
./install.sh --libadwaita         # also restyle GTK4/libadwaita applications
./install.sh --apply              # build, then select it in Plasma
./install.sh --remove             # uninstall
```

## Applying it

Building only writes files into `~/.themes`; something still has to select the
theme. Use either *System Settings → Appearance → Application Style → Configure
GNOME/GTK Application Style*, or `./install.sh --apply`, which calls the same
service System Settings does:

```bash
qdbus-qt6 org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme FluidSur-Light
```

**Do not set it by hand** in `~/.config/gtk-3.0/settings.ini`. Plasma keeps its
own record of the GTK theme and feeds XSETTINGS from that, so hand-editing the
file only half applies: GTK applications running under XWayland keep the old
theme while native Wayland ones switch, and the two disagree indefinitely.

Running applications do not reload GTK themes; restart them to see the change.

### If the window buttons have a black ring around them

Older kde-gtk-config versions write `~/.config/gtk-3.0/window_decorations.css`,
which replaces every GTK titlebutton image with a Qt rasterisation of the
current Aurorae buttons. It is loaded at CSS provider priority 801 — above both
the theme (200) and your own `~/.config/gtk-3.0/gtk.css` (800) — so nothing in
this theme can override it.

Those rasterised copies are the problem: Qt's SVG generator serialises
`QPainter::pen()`, which is still solid black on fill-only shapes, so any filled
part of a button picks up a heavy dark outline. In Chrome it also comes out
oversized, because Chrome injects `background-size: contain` at priority 600 and
the image scales to whatever the button is allocated.

Setting the theme through kde-gtk-config (above) removes that file — Plasma 6
deprecated it. If it comes back, deleting it is safe; the theme supplies its own
button images.

## Layout

```
src/main/gtk-{2.0,3.0,4.0}   per-toolkit entry points and gresource manifests
src/sass/                    stylesheet sources (compiled with sassc)
src/assets/gtk/              shared widget art
  └ windows-assets/          the window buttons themselves
src/assets/gtk-2.0/          GTK 2 pixmap art
```

The window buttons live in `src/assets/gtk/windows-assets/titlebutton*/` as PNGs
(normal, hover, active and backdrop states, each with a `@2` HiDPI variant) and
are wired up by the `button.titlebutton` rules in
`src/sass/gtk/_common-3.0.scss` and `_common-4.0.scss`. Changing their look
means replacing those PNGs and rebuilding — there is no other magic involved.

## Licensing

Adapted from [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
by Vince Liuice, MIT licensed. The original license text is kept in `COPYING`;
see `../NOTICE.md` for the full attribution.
