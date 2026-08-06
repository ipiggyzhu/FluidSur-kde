# FluidSur — Firefox

Firefox draws its own window buttons. It reads GTK for their *order* and *side*,
but not for their appearance, and the old escape hatch
(`widget.gtk.non-native-titlebar-buttons.enabled`) was removed from the codebase
— it is no longer present in `libxul.so`. So a GTK theme alone can never give
Firefox the FluidSur window buttons.

`userChrome.css` is the one remaining hook, and it is what this component uses.

## Strengths

| Mode | What changes |
| --- | --- |
| `full` (default) | Whole browser chrome: capsule tabs, floating rounded address bar, restyled menus, popups, sidebar, find bar, dialogs, notifications, video controls, and the FluidSur window buttons |
| `buttons` | Only the three window buttons. Everything else stays stock Firefox |

Use `buttons` if you like Firefox's own layout and only want the window controls
to match the rest of the desktop.

## Variants

`default`, `darker`, `adaptive`, `nord` — passed with `--variant`. `adaptive`
follows the page's own colours; `nord` uses the Nord palette and its own
titlebutton artwork.

## Usage

```bash
./install.sh                        # full, default variant, every profile found
./install.sh --mode buttons         # window buttons only
./install.sh --variant nord         # Nord palette
./install.sh --profile ~/.config/mozilla/firefox/xxxx.default-release
./install.sh --remove
```

Restart Firefox afterwards. `about:support` → *Profile Directory* tells you which
profile is actually in use if you have several.

## Profile discovery

Firefox moved Linux profiles out of `~/.mozilla` in version 138, and the packaged
builds keep their own copies, so all four locations are searched:

```
~/.mozilla/firefox                                 (pre-138)
~/.config/mozilla/firefox                          (current)
~/.var/app/org.mozilla.firefox/.mozilla/firefox    (Flatpak)
~/snap/firefox/common/.mozilla/firefox             (Snap)
```

Directories matching `*.default*` are treated as profiles. Pass `--profile` to
override.

## What it touches

```
<profile>/chrome/                 the theme (replaced wholesale)
<profile>/user.js                 a delimited block, appended
```

Both are handled non-destructively:

- An existing `chrome/` that this installer did not create is moved aside to
  `chrome.pre-fluidsur` and restored on `--remove`.
- `user.js` is **never** truncated. The installer maintains a block between
  `/* >>> FluidSur theme begin */` and `/* <<< FluidSur theme end */`, and
  rewrites only that block. Your own prefs above and below it are left alone,
  and a one-time copy is kept at `user.js.pre-fluidsur`.

The prefs it sets:

| Pref | Why |
| --- | --- |
| `toolkit.legacyUserProfileCustomizations.stylesheets` | required for `userChrome.css` to load at all |
| `svg.context-properties.content.enabled` | lets the SVG icons pick up theme colours |
| `browser.uidensity` | `full` only — normal density, the theme's metrics assume it |
| `widget.gtk.rounded-bottom-corners.enabled` | `full` only — rounded bottom corners |
| `mozilla.widget.use-argb-visuals` | `full` only — needed for the rounded corners to be transparent |

The installer does not kill a running Firefox; it prints a reminder instead.

## Customising

`<profile>/chrome/customChrome.css` is imported last and is yours. It survives
nothing — a re-install overwrites the whole `chrome/` directory — so keep the
master copy in `firefox/src/customChrome.css` in this repo if you want it to
persist across installs.

`<profile>/chrome/userChrome.css` also carries a set of commented-out optional
imports (move the tab close button to the left, hide the tab bar when a single
tab is open, symbolic tab icons, and so on). Uncomment to enable.

## Known gaps

Inherited from upstream and not yet fixed here:

- `parts/titlebutton-light-alt.css` and `parts/titlebutton-dark-alt.css`
  reference artwork that was never shipped. Nothing imports them, so they are
  inert.
- A handful of icons referenced by `parts/icons.css`,
  `parts/headerbar-private-urlbar.css` and `parts/tabsbar-adaptive.css` are
  missing (`phone-symbolic`, `tab-restore-symbolic`, `url2qr-icon`,
  `user-not-tracked-dark`, `window-close-symbolic-light`). Those few elements
  fall back to Firefox's own icons.

## Licensing

Derived from [WhiteSur-gtk-theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
(`other/firefox`), MIT. See `../NOTICE.md`.
